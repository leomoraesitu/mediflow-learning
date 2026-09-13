module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  transform: {
    // Aponta para o tsconfig de desenvolvimento, que é quem declara os tipos
    // do jest. Sem isto o ts-jest usa o tsconfig de produção, e o tipo do
    // runner voltaria a ter que morar lá.
    "^.+\\.tsx?$": ["ts-jest", {tsconfig: "tsconfig.dev.json"}],
  },
};
