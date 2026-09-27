# retrykit

Retry async calls with exponential backoff. No dependencies.

## Install

    npm install retrykit

## Use

```js
import { retry, retryDelay } from 'retrykit';

const user = await retry(() => fetchUser(id), { retries: 5, timeout: 5000 });

// the delay retry waits before attempt 3
retryDelay(3); // 400
```

Options: `retries` (default 3), `timeout` per attempt in milliseconds
(default 10000), `baseMs`, `maxMs`.

## Develop

    make check
