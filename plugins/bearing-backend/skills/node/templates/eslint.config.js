import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import { createTypeScriptImportResolver } from "eslint-import-resolver-typescript";
import importX, { createNodeResolver } from "eslint-plugin-import-x";
import globals from "globals";
import tseslint from "typescript-eslint";

// Flat config. Strict type-checked TypeScript and import order; Prettier
// owns formatting. drizzle/ holds generated SQL and JSON, not linted.
export default tseslint.config(
  { ignores: ["dist/**", "coverage/**", "node_modules/**", "drizzle/**"] },
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  importX.flatConfigs.recommended,
  importX.flatConfigs.typescript,
  {
    files: ["**/*.ts"],
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
      globals: { ...globals.node },
    },
    settings: {
      "import-x/resolver-next": [
        createTypeScriptImportResolver({ project: "./tsconfig.json" }),
        createNodeResolver(),
      ],
    },
    rules: {
      "import-x/order": [
        "error",
        {
          groups: ["builtin", "external", "internal", ["parent", "sibling", "index"]],
          "newlines-between": "always",
          alphabetize: { order: "asc", caseInsensitive: true },
        },
      ],
      "@typescript-eslint/consistent-type-imports": ["error", { fixStyle: "inline-type-imports" }],
      "@typescript-eslint/no-unnecessary-condition": [
        "error",
        { allowConstantLoopConditions: true },
      ],
      "@typescript-eslint/restrict-template-expressions": ["error", { allowNumber: true }],
      // pino is the logger; console is for the process boundary only.
      "no-console": ["error", { allow: ["error"] }],
    },
  },
  {
    files: ["**/*.test.ts", "tests/**/*.ts"],
    rules: { "@typescript-eslint/no-non-null-assertion": "off" },
  },
  {
    files: ["*.config.{ts,js}"],
    rules: {
      "import-x/no-named-as-default": "off",
      "import-x/no-named-as-default-member": "off",
    },
  },
  { files: ["**/*.js"], ...tseslint.configs.disableTypeChecked },
  prettier,
);
