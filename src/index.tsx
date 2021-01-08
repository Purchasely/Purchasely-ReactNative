import { NativeModules } from 'react-native';

type PurchaselyType = {
  multiply(a: number, b: number): Promise<number>;
};

const { Purchasely } = NativeModules;

export default Purchasely as PurchaselyType;
