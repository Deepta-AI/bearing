import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { HttpInstrumentation } from "@opentelemetry/instrumentation-http";
import { PgInstrumentation } from "@opentelemetry/instrumentation-pg";
import { PinoInstrumentation } from "@opentelemetry/instrumentation-pino";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { NodeSDK } from "@opentelemetry/sdk-node";
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from "@opentelemetry/semantic-conventions";

export interface TelemetryOptions {
  /** OTLP/HTTP collector base URL. Empty or undefined means tracing stays off. */
  endpoint?: string | undefined;
  serviceName: string;
  version: string;
}

const PROBE_PATHS = /^\/(healthz|readyz|metrics)$/;

/**
 * startTelemetry is a no-op until OTEL_EXPORTER_OTLP_ENDPOINT is set; then
 * spans export over OTLP/HTTP and http, pg and pino are instrumented. It
 * must run before those modules load, which is why server.ts imports the
 * app dynamically after calling it. Nothing else in the service imports
 * opentelemetry.
 */
export function startTelemetry(options: TelemetryOptions): NodeSDK | null {
  const endpoint = options.endpoint?.trim().replace(/\/+$/, "");
  if (!endpoint) {
    return null;
  }
  const sdk = new NodeSDK({
    resource: resourceFromAttributes({
      [ATTR_SERVICE_NAME]: options.serviceName,
      [ATTR_SERVICE_VERSION]: options.version,
    }),
    traceExporter: new OTLPTraceExporter({ url: `${endpoint}/v1/traces` }),
    instrumentations: [
      new HttpInstrumentation({
        ignoreIncomingRequestHook: (request) => PROBE_PATHS.test(request.url ?? ""),
      }),
      new PgInstrumentation(),
      new PinoInstrumentation(),
    ],
  });
  sdk.start();
  return sdk;
}
