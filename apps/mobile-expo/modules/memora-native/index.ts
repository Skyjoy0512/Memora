// Re-export the native module. On web, it will be resolved to MemoraNativeModule.web.ts
// and on native platforms to MemoraNativeModule.ts
export { default } from './src/MemoraNativeModule';
export * from './src/MemoraNative.types';
