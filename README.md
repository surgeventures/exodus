# Exodus

Migrate multiple repositories to monorepo.

## Usage

First, copy `config/config.example.exs` to `config/config.exs` and fill it with real information
about your repositories.

Then, compile and install the script:

```
mix deps.get
mix escript.build
mix escript.install
```

Now, you can invoke the `exodus` command from any working directory that you choose.
