


<!--#-->
### How to Mock Axios Adapter
axios adapter 是 axios 源碼中負責處理 http/xhr request 的部份，如果直接 mock axios 裡的 request|get|put|del|... 這些方法，會中斷 axios 內部的邏輯（即 interceptors)，axios request 方法會呼叫 dispatchEmit, 而 dispatchEmit 會引用 adapter，所以如果真的要 mocking axios response 而不影響 axios 的內部邏輯，最好的方法是直接 mock adapter，方法只要在 AxiosRequestConfig 中注入自定義 Adapter 即可，透過 mockAdapter，可以決定應該返從 server 端返回什麼值。


#### AxiosRequestConfig 自定義 Adapter
如下例，axios.create 所創建的 instance 均使用自定義 Adapter | [source][s-test-mocking]

```ts
function mockAxiosCreate(
  mockAxios: jest.Mocked<AxiosStatic>,
  mockServer: MockedServer,
  mockAdapter: jest.Mocked<any>
) {
  const origCreate = jest.spyOn(axios, "create") as any;
  let instances: jest.Mocked<AxiosInstance>[] = [];

  mockAxios.create = ((config: CreateAxiosDefaults) => {
    // 直接將 adapter 塞入 config
    config.adapter = mockAdapter as any;
    const _origInst = origCreate(config);
    const _origRequest = _origInst.request.bind(_origInst);
    assert(() => _origInst != undefined);
    ...
```

#### 自定義 Adapter
如下例，adapter 的作用，除了 set header 便是由 server 取得 response, 這宙多了一個mockServer 用來模擬 server 端的資料，如處理 request header 是否正確, 是否該 throw unauthorized error
```ts
function getMockedAdapter(mockServer: MockedServer): jest.Mock<any> {
  const mockAdapter = jest.fn((config) => {
    config.headers.set("User-Agent", "axios/" + "1.2.1", false);
    const response = mockServer.getResponse(config);
    config.data = response;
    return response;
  });
  (mockAdapter as any).__name__ = "mockAdapter";
  return mockAdapter;
}
```

### Mock Server Response
__型別__ | [source][s-test-mocking]
```ts
abstract class IMockedServer {
  abstract setHeaderValidator(
    validator: (
      config: AxiosRequestConfig
    ) => AxiosResponse | AxiosError | undefined | null
  ): void;
  abstract registerResponse(
    url: string,
    response: any,
    useValidator: boolean
  ): void;
  abstract getResponse(
    config: AxiosRequestConfig
  ): Promise<AxiosResponse | AxiosError>;
}
```

#### registerResponse
針對特定的請求 url 註冊返回一個特定的結果 response (mockResult)

```ts
registerResponse(
  url: string,response: any,
  useValidator: boolean
): void;
```

__example__
| [source][s-test-helper]
```ts
const _url = (new URL(url, 'http://localhost'))
_url.search = new URLSearchParams(payload).toString();
//針對 url mock result
mockServer.registerResponse(url, result());
expect(client.get(url, payload)).resolves.toEqual(result())
```

#### getResponse
由 mockServer 取回 response, 於 adapter 內呼叫
```ts
getResponse(config: AxiosRequestConfig): Promise<AxiosResponse | AxiosError>;
```

#### setHeaderValidator
mockServer 用來驗證 request header 是否正確, 以返回錯誤的 response，如下驗證 auth token 是否正確, 若正確返回null, 若不正確返回 axios.HttpStatusCode.Unauthorized:

```ts
mockServer.setHeaderValidator((config: AxiosRequestConfig) => {
  try {
    const token = (config.headers as AxiosHeaders).get("Authorization");
    const authorized = token == authToken.value;
    // 無錯誤
    if (authorized) return null;

    const name = "Unauthorized";
    const message = name;
    const statusText = name;
    const response: AxiosResponse = {
      data: {
        message,
        error_name: name,
        error_code: axios.HttpStatusCode.Unauthorized,
        error_key: name,
      },
      status: axios.HttpStatusCode.Unauthorized,
      statusText,
      headers: {},
      config,
    };
    return response;
  } catch (e) {
    console.error("setAuthHeaderGuard failed, config:", config);
    throw e;
  }
});
```

### Mock Axios.create
```ts
mockAxios.create = ((config: CreateAxiosDefaults) => {
  config.adapter = mockAdapter as any;
  const _origInst = origCreate(config);
  const _origRequest = _origInst.request.bind(_origInst);
  assert(() => _origInst != undefined);

  const inst: jest.Mocked<AxiosInstance> = jest.mocked(_origInst);
  jest.spyOn(inst, "get");
  jest.spyOn(inst, "put");
  jest.spyOn(inst, "delete");
  jest.spyOn(inst, "post");
  jest.spyOn(inst, "request");

  assert(() => inst != undefined);
  assert(() => inst.get.mock != undefined);

  instances.push(inst);
  const origUseRequest = inst.interceptors.request.use.bind(
    inst.interceptors.request
  );
  const origUseResponse = inst.interceptors.response.use.bind(
    inst.interceptors.response
  );
  inst.interceptors.request.use = jest.fn((fulfilled, rejected, options) => {
    return origUseRequest(fulfilled, rejected, options);
  }) as any;
  inst.interceptors.response.use = jest.fn((fulfilled, rejected, options) => {
    return origUseResponse(fulfilled, rejected, options);
  }) as any;
  return inst;
}) as any;
```