/**
 * v6 public surface — exported from the package root via `react-native-purchasely`.
 * The legacy v5 API remains available alongside this module for backward
 * compatibility, but is marked `@deprecated`.
 *
 * Contract: reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md
 */

export * from './types';
export { PURCHASELY_V6_EVENTS } from './events';
export { PresentationBuilder, PresentationRequest } from './presentation';
export {
    interceptAction,
    removeActionInterceptor,
    removeAllActionInterceptors,
} from './interceptor';
export { PurchaselyBuilder } from './startBuilder';
