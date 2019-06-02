use Mix.Config

config :kvstore,
       storage: StorageMock,
       tab_name: :kv_store_test