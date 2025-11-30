%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          # Allow nested modules for test support files and generated Phoenix code
          {Credo.Check.Design.AliasUsage,
           excluded_namespaces: ~w[Phoenix Ecto ExAws],
           excluded_lastnames: ~w[HTML Controller Repo Router Endpoint JSON],
           if_nested_deeper_than: 2},

          # Allow higher complexity for scoring algorithms
          {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 26}
        ],
        disabled: []
      }
    }
  ]
}
