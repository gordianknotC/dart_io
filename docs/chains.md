
---
<!--#-->
### Request/Response 流程

實作主要建立在 axios 處理 interceptor 流程的基礎上，只是用 responsibility chain 的設計模式模組化，原 axios interceptors 有二個部份，即 Request/Response 各自分為 onFulFill/onReject 二個流程

- Request
  - onFulFill
    - canProcessFulFill > processFulFill
  - onReject
    - canProcessReject > processReject
- Response
  - onFulFill
    - canProcessFulFill > processFulFill
  - onReject
    - canProcessReject > processReject

每個流程都必需實作 canProcess/process 二個方法, canProcess 用來定是否能夠進入 process， process 則用來處理上一個 chain 所輪出的值，處理後再丟給下一個 chain 的 process 作為下一個 chain 的輪入值.

> 意即在原來的 interceptor 中插入

```ts
axios.interceptors.response.use(
  function(requestConfig){
    if (chain1.canProcessOnFulFill(requestConfig)){
      requestConfig = chain1.processFulFill(requestConfig)
    }
    if (chainN.canProcessOnFulFill(requestConfig)){
      ...
    }
  },
  function(error){
	// ...
  })
```

> 若用責任鍊自我遞迴的方式改寫

```ts
function processResponseFulFill(
  response: AxiosResponse,
  chain?: BaseClientServicesPluginChains<any, any, any>
): Promise<AxiosResponse> {
  if (!chain)
    return Promise.resolve(response); // 結束責任鍊
  if (ensureCanProcessFulFill(() => onStage(chain, response, EMethod.canProcessFulFill))) {
    return onStage(chain, response, EMethod.processFulFill); // chain
  } else {
    if (chain.next && chain.canGoNext(response.config!)) {
      return processResponseFulFill(response, chain.next); // next chain
    }
    return processResponseFulFill(response, undefined);
  }
}

function onResponseFulFilled(chain: BaseClientServicesPluginChains){
  return (response: AxiosResponse): Promise<AxiosResponse> => {
    return processResponseFulFill(response, chain);
  }
}

axios.interceptors.response.use(
	onResponseFulFilled(masterChain),
	onResponseReject(masterChain)
)
axios.interceptors.request.use(
	...
)
```

以上當 chain undefined 時， return Promise.resolve 結束責任鍊，其他狀態則續繼下一個責任鍊，canProcessFulFull 為當前 chain 用來判定是否執行的依據，canGoNext 則是當前 chain 用來控制是否執行下一個 chain 的依據，預設為 true, 不建議 override 這個值。

```ts
/** default: true */
public canGoNext(config: INPUT): boolean {
	return this.next != undefined;
}
```

Chain 共分為二大類，ResponseChain / RequestChain 分別對應 axios.interceptors.response / axios.interceptors.request，每個 Chain 再各自分為 onFulFill / onReject 分別用作 Promise resolve / Promise reject 的非同部流程，以下分別就這幾個流程作細部說明。

#### ResponseChain

##### onFulFill/onReject 流程

```mermaid
flowchart LR;
	subgraph ResolveChainOfResponse - ResponseChain-FulFill
		direction TB
    	subgraph PluginN
			direction TB
			canProcessFulFillN-->|Y|processFulFillN-->|path-of-chain\ncontinuing-the-reset-of-chains|nextN+1
			canProcessFulFillN-->|N|nextN+1
		end

		subgraph processFulFillN[returned value in processFulFill determines the next flow]
			direction LR
			this.resolve-.->|resolve current chain\nand continue the rest|Next\nResolveChainOfResponse
      		this.resolveAndIgnoreAll-.->|resolve current chain\nand breaking the reset|resolve_
			this.reject-.->|reject current chain\nand continue the reset|Next\nRejectChainOfResponse
			this.rejectAndIgnoreAll-.->|resolve current chain\nand breaking the reset|reject_
		end

		subgraph nextN+1[Next\nChain]
			direction TB
		end

		ResponseInput[response input\nAxiosResponse]==>PluginN
		nextN+1==>ResponseOutput[ResponseOutput\nAxiosError/AxiosResponse]
		nextN+1-->nextN+1

		processFulFillN-....->|path-of-reject\nbreaking-the-rest-of-chains|reject
		processFulFillN-....->|path-of-resolve\nbreaking-the-rest-of-chains|resolve
		ResponseOutput==>User
		resolve==>AxiosResponse
    	AxiosResponse==>User
		reject==>AxiosError==>User
	end
```

> - canProcessFulFill 決定是否進入 processFulFill, 若否則走下一個 chain
> - processFulFill 實作時其返回值會導致 axios 在處埋 interceptors 分別走上不同的路徑
>   - return this.resolve
>     resolve 當前 chain 並繼續 resolve 下一個 ResponseChain
>   - return this.rejectAndIgnoreAll(即 Promise.reject)
>     進入 ResponseChain-onReject 路徑
>   - return this.reject
>     reject 當前 chain 並繼續 reject 下一個 ResponseChain
>   - return this.resolveAndIgnoreAll(即 Promise.resolve)
>     resolve 當前 chain 並結束整個 response chain

##### resolve

resolve response 並且繼續下一個 response chain

```ts
protected resolve<T = AxiosResponse<any, any> | AxiosRequestConfig<any>>(configOrResponse: T): Promise<T>
```

##### resolveAndIgnoreAll

resolve response 並結束整個 response chain

```ts
protected resolveAndIgnoreAll<T = AxiosResponse<any, any> | AxiosRequestConfig<any>>(configOrResponse: T): Promise<T>
```

##### reject

reject response 並且繼續下一個 response chain

```ts
protected reject<T = AxiosResponse<any, any> | AxiosError<unknown, any> | AxiosRequestConfig<any>>(input: T): Promise<T>
```

##### rejectAndIgnoreAll

reject response 並結束整個 response chain

```ts
protected rejectAndIgnoreAll<T = AxiosResponse<any, any> | AxiosError<unknown, any> | AxiosRequestConfig<any>>(input: T): Promise<T>
```

##### processFulFill

axios response interceptor onFulFill 時執行，
覆寫請記得 return this.resolve responsibility chain
不會繼續.

```ts
processFulFill(response: AxiosResponse): Promise<AxiosResponse>
```

##### processReject

axios response interceptor onReject 時執行，
覆寫請記得 return this.reject，不然 responsibility chain
不會繼續.

```ts
processReject(error: AxiosError): Promise<AxiosError | AxiosResponse>
```

#### RequestChain

##### onFulFill/onReject 流程

```mermaid
flowchart LR;
	subgraph ResponseChain-FulFill
		direction TB
    	subgraph PluginN
			direction TB
			canProcessFulFillN-->|Y|processFulFillN-->|path-of-chain\ncontinuing-the-reset-of-chains|nextN+1
			canProcessFulFillN-->|N|nextN+1
		end

		subgraph processFulFillN[returned value in processFulFill determines the next flow]
			direction LR
			this.resolve-.->|resolve current chain\nand continue the rest|Next\nResolveChainOfResponse
      		this.resolveAndIgnoreAll-.->|resolve current chain\nand breaking the reset|resolve_
			this.reject-.->|reject current chain\nand continue the reset|Next\nRejectChainOfResponse
			this.rejectAndIgnoreAll-.->|resolve current chain\nand breaking the reset|reject_
		end

		subgraph nextN+1[Next\nChain]
			direction TB
		end

		subgraph ResponseChain
			direction TB
			resolveChain-->AxiosResponse_
			rejectChain-->AxiosError_
		end

		nextN+1-->nextN+1
		RequestInput==>PluginN
		nextN+1==>RequestOutput==>AxiosAdapter
		RemoteServer==>AxiosAdapter
		AxiosAdapter==>ResponseChain
		ResponseChain==>toUser[User]

		processFulFillN-....->|path-of-resolve\nbreaking-the-rest-of-chains|resolve
		processFulFillN-....->|path-of-reject\nbreaking-the-rest-of-chains|reject
		resolve==>RequestOutput
		reject==>AxiosError==>toUser
	end
```

##### resolve

resolve request 並且繼續下一個 request chain

```ts
resolve<T=AxiosRequestConfig<any>>(configOrResponse: T): T
```

##### resolveAndIgnoreAll

resolve request 並結束整個 request chain

```ts
resolveAndIgnoreAll<T = AxiosResponse<any, any> | AxiosRequestConfig<any>>(configOrResponse: T): Promise<T>
```

##### reject

reject request 並且繼續下一個 request chain

```ts
reject<T = AxiosResponse<any, any> | AxiosError<unknown, any> | AxiosRequestConfig<any>>(input: T): Promise<T>
```

##### rejectAndIgnoreAll

reject request 並結束整個 request chain

```ts
rejectAndIgnoreAll<T = AxiosResponse<any, any> | AxiosError<unknown, any> | AxiosRequestConfig<any>>(input: T): Promise<T>
```

##### processFulFill

axios request interceptor onFulFill 時執行，
覆寫請記得 return this.resolve responsibility chain
不會繼續.

```ts
processFulFill(config: AxiosRequestConfig): AxiosRequestConfig
```

##### processReject

axios request interceptor onReject 時執行，
覆寫請記得 return this.reject，不然 responsibility chain
不會繼續.

```ts
processReject(error: AxiosError): Promise<any>
```


---


### 常用 Request Chain
#### RequestReplacer

透過 canProcessFulFill 用來選擇什麼情況下要取代當前的 request, 當 canProcessFulFill 為 true 時，進入 processFulFill 以取代當前的 request， 如下例：

> 當 client stage 為 authorizing 時，代表此時 client 正在取得 authorization token, 這時任何的 request 所送出的 authorization token 均將會是舊的，在取得 authorization token 前，任何 request 都應放入駐列中容後處理，直到 authorization token 換發成功後，再處理駐列中的請求，而 Request Replacer 正是用於這一類的情境

[source](#s-requestReplacer)

````ts
/**
 * {@inheritdoc BaseRequestGuard}
 *
 * 使用情境如，當第一個 request 出現 Unauthorized 錯誤時，
 * 後續所有的 request 在第一個 request 重新換發 token 並返回正確的 request 前, 都
 * 需要等待，這時就需要直接取代 request, 讓它保持 pending 待第一個 request 換發成功
 * 後再行處理，流程為
 * - request
 *    {@link canProcessFulFill} > {@link processFulFill}
 * - response
 *    {@link canProcessReject} > {@link processReject}
 *
 * @typeParam RESPONSE - response 型別
 * @typeParam ERROR - error 型別
 * @typeParam SUCCESS - success 型別
 */
export class RequestReplacer<
  RESPONSE,
  ERROR,
  SUCCESS
> extends BaseRequestReplacer<RESPONSE, ERROR, SUCCESS> {
  /**
   * 當 {@link canProcessFulFill} 為 true 則可以進行 {@link processFulFill}，這裡
   * {@link canProcessFulFill} 只處理當 client 狀態為 {@link EClientStage.authorizing} 時，
   * 代表client正處於換發 authorization token， 這時應處理所有進來的 request, 替代成 pending
   * @returns -
   * ```ts
   * this.client!.stage == EClientStage.authorizing
   * ```
   * */
  canProcessFulFill(config: AxiosRequestConfig<any>): boolean {
    return this.client!.stage == EClientStage.authorizing;
  }
  /**
   * @extendSummary -
   * 當{@link canProcessFulFill}成立，強制將 request raise exception, 好進行至
   * reject進行攔截
   * */
  processFulFill(config: AxiosRequestConfig<any>): AxiosRequestConfig<any> {
    return this.switchIntoRejectResponse(config, BaseRequestReplacer.name);
  }

  /** false */
  canProcessReject(error: AxiosError<unknown, any>): boolean {
    return false;
  }
}
````

### 常用 Response Chain
#### AuthResponseGuard

用來處理當 request 發出後, 於 response 出現 401/Unauthorized error，這時原有的 request 會被放入駐列中保留，待 auth token 成功換發完後再次送出，處理流程為

- canProcessFulFill 
  - processFulFill
    - onRestoreRequest - 保留請求
    - onRequestNewAuth - 換發 auth token
      - onAuthError - 當 auth token 換發失败
      - onAuthSuccess - 當 auth token 換發成功
      - onAuthUncaughtError - 當 auth token 換發錯誤

[source](#s-authResponseGuard)

```ts
export class AuthResponseGuard extends BaseAuthResponseGuard {
  /** ### 用來定義當 unauthorized error 後，auth token 換發時的主要邏輯, 預設為 this.client.auth()
   * @param error - {@link AxiosError}
   * @param pendingRequest - 由{@link onRestoreRequest} 所生成的 pendingRequest，
   * 其內容為一個永不 resolve 的 Promise 物件，直到 auth token 重新換發後再次重新送出原請求，才
   * 會更新 pendingRequest 的內容，在這之前 pendingRequest 的 Promise 物件會一直保持 pending，
   * 除非 timeout
   */
  protected onRequestNewAuth(error: AxiosError): Promise<AxiosResponse> {
    return super.onRequestNewAuth(error);
  }

  /** ### 用來生成代替 unauthorized error 的空請求
   * 當 unauthorized error 後，auth token 換發前，會生成一個空的 Promise 請求，
   * 以代替原請求因 unauthorized error 所產生的錯誤，{@link BaseAuthResponseGuard} 會先
   * 返回這個空的 Promise 好讓原 axios 的請求持續等待。
   * @param error - {@link AxiosError}
   * @returns - {@link Completer<any, QueueItem>}
   */
  protected onRestoreRequest(error: AxiosError): Completer<any, QueueItem> {
    return super.onRestoreRequest(error);
  }

  protected async reject<
    T =
      | AxiosResponse<any, any>
      | AxiosRequestConfig<any>
      | AxiosError<unknown, any>
  >(input: T): Promise<T> {
    try {
      const error = input as AxiosError;
      const pending = this.onRestoreRequest(error);
      D.info([
        "onRestoreRequest A",
        error.config?.url,
        this.client?.queue.queue.length,
      ]);
      const authResponse = await this.onRequestNewAuth(error);
      return pending.future;
    } catch (e) {
      throw e;
    }
  }

  processReject(
    error: AxiosError<unknown, any>
  ): Promise<AxiosResponse<any, any> | AxiosError<unknown, any>> {
    if (
      this.isDirtiedBy(
        error,
        ACAuthResponseGuard.name,
        ChainActionStage.processResponse
      )
    ) {
      return this.rejectAndIgnoreAll(error);
    }
    return this.reject(error);
  }
}
```

### 常用 Response Chain - for auth-specific axios instance
為了在流程上方便撰寫，專門化一個 axios instance（以下暫稱AuthClient/AcXXX） 獨立於一般性的 axios interceptors，用來處理換發auth token 時的 Response/Request Chain, 與一般性的 Response/Request Chain 分開

- AuthClientStageMarker 
  用來標定目前的 auth client 的 stage
  - ACFetchedMarker (標定為 fetched)
  - ACIdleMarker (標定為 idle)
- ACTokenUpdater
  用來更新 token
- ACAuthResponseGuard
  當換發成功後，處理駐列中的請求

#### ACFetchedMarker
用來標定目前的 AuthClient [stage](#-eclientStage) 處於 auth token fetched 階段 

[source](#s-acFetchedMarker)
```ts
/** 用來標定目前的 auth client stage 處於 auth token fetched 階段 
 * @see {@link EClientStage}
*/
export class ACFetchedMarker extends AuthClientStageMarker {
  canProcessFulFill(config: AxiosResponse<any, any>): boolean {
    this.client!.markFetched();
    return super.canProcessFulFill(config);
  }
  canProcessReject(error: AxiosError<unknown, any>): boolean {
    this.client!.markFetched();
    return super.canProcessReject(error);
  }
}
```

#### ACIdleMarker
用來標定目前的 AuthClient [stage](#-eclientStage) 處於 idle 階段 
[source](#s-acIdleMarker)
```ts
export class ACIdleMarker extends AuthClientStageMarker {
  canProcessFulFill(config: AxiosResponse<any, any>): boolean {
    this.client!.markIdle();
    return super.canProcessFulFill(config);
  }
  canProcessReject(error: AxiosError<unknown, any>): boolean {
    this.client!.markIdle();
    return super.canProcessReject(error);
  }
}
```

#### ACTokenUpdater
當 auth token 成功取得後，用來更新當前前的 auth token，並將標定目前的 AuthClient stage 處於 updated 階段 
[source](#s-acTokenUpdater)
```ts
export class ACTokenUpdater extends AuthClientResponseGuard {
  canProcessFulFill(response: AxiosResponse<any, any>): boolean {
    return this.host.isDataResponse(response)
      && (response.status == axios.HttpStatusCode.Ok);
  }
  processFulFill(response: AxiosResponse<any, any>): Promise<AxiosResponse<any, any>> {
    this.client?.option.tokenUpdater(response)
    D.current(["ACTokenUpdater:", response.data, this.client?.option.tokenGetter()])
    if (this.client?.option.tokenGetter() == undefined){
      throw new Error("Unexpected tokenGetter/tokenUpdater");
    }
    this.client?.markUpdated();
    return this.resolve(response);
  }
  canProcessReject(error: AxiosError<unknown, any>): boolean {
    return false;
  }
}
```

#### ACAuthResponseGuard
處理以下請況

1) 用來處理當非AuthClient 送出的請求於遠端返回 unauthorized error (response error) 發生後 AuthResponseGuard 會將原請求放到駐列中，並透過 AuthClient 發出換發 token 請求, AuthClient interceptor 透過讀取當 auth token 成功換發且更新後，若駐列中有未完成的請求，則 ACAuthResponseGuard 會負責將這些請求重新送出
  
2) 當 AuthClient 換發 token 失敗

[source](#s-acAuthResponseGuard)



### 目前實作上的缺點
- 責任鍊有前後相依性，目前正以 GroupChain / GeneralChain 的方式改善




