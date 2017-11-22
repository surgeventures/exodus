# Exodus

Migrate multiple repositories to monorepo.

## Usage

First, copy `config/config.local.example.exs` to `config/config.local.exs` and fill it with real
information about your repositories, paths and other required settings.

Then, compile and install the script:

```
mix deps.get
mix escript.build
mix escript.install
```

Now, you can invoke the `exodus` command from any working directory that you choose.

Alternatively, you can quickly run the script directly in the `exodus` root:

```
mix escript.build && ./exodus
```
