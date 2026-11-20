/**
 * The four legacy purchase listener calls are deprecated in 6.3.0 (MOB-646).
 * The published declarations keep only the JSDoc that sits on a property of
 * the default export: a tag on the `const` alone does not reach an app.
 */
import * as fs from 'fs';
import * as path from 'path';
import * as ts from 'typescript';

const DEPRECATED = [
  'addPurchasedListener',
  'listenToPurchases',
  'removePurchasedListener',
  'stopListeningToPurchases',
];

const defaultExportProperties = (): ts.ObjectLiteralElementLike[] => {
  const file = path.join(__dirname, '..', 'index.ts');
  const source = ts.createSourceFile(
    file,
    fs.readFileSync(file, 'utf8'),
    ts.ScriptTarget.Latest,
    true
  );
  let found: ts.ObjectLiteralExpression | undefined;
  const visit = (node: ts.Node) => {
    if (
      ts.isVariableDeclaration(node) &&
      node.name.getText() === 'Purchasely' &&
      node.initializer &&
      ts.isObjectLiteralExpression(node.initializer)
    ) {
      found = node.initializer;
    }
    node.forEachChild(visit);
  };
  visit(source);
  if (!found) throw new Error('default export object not found');
  return [...found.properties];
};

describe('legacy purchase listeners', () => {
  it('carry @deprecated on the properties of the default export', () => {
    const tagged = defaultExportProperties()
      .filter((p) => p.name && ts.getJSDocDeprecatedTag(p))
      .map((p) => p.name!.getText())
      .filter((name) => DEPRECATED.includes(name))
      .sort();
    expect(tagged).toEqual(DEPRECATED);
  });
});
