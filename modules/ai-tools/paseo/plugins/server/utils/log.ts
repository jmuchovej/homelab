import { ConsolaInstance, ConsolaOptions, createConsola } from "consola/core";

export function useLogger(name: string, options?: ConsolaOptions): ConsolaInstance {
  return createConsola(options).withTag(name);
}
