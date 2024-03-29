**Kvstore**

**Тестовое задание**

На языке Elixir написать key-value хранилище с удалением данных по таймауту (TTL) и управлением (CRUD) через http. TTL задается клиентом при добавлении пары key-value в хранилище. Необходимо обезопасить приложение от потери данных между перезапусками. Выполнив задание, отправьте нам ссылку на репозиторий с решением. При решении задачи не допускается создание форков с исходного репозитория

**Описание реализации**

В качестве постоянного хранилища данных используется DETS (название таблицы задается в настройках). Данные хранятся в кортежах вида 
{Ключ, Значение, Время до которого данные должны храниться (expiry_time)}.

Разрешеннын действия над данными:
1. добавление записи

2. удаление записи

3. изменение значения записи

4. изменение срока хранения записи

5. получение записи по ключу

6. получение всех записей

7. получение срока жизни записи по ключу


После выполнения действий добавление, удаление, изменения срока хранения записи происходит запись в таблицу сроков истечения записей (ETS таблицу типа ordered_set - упорядоченное множество, реализовано в виде сбалансированного дерева). Вид данных в этой таблице: 
{Время (срок истечения, соответствует expiry_time для DETS таблицы, ключ), MapSet ключей срок хранения которых истекает в это время}


По данной таблице планируется следующее удаление неактуальных данных из таблицы DETS, путем посылание сообщения с таймаутом равным времени до истечения срока хранения записей с наименьшим expiry_time. После каждой операции добавление, удаление, изменения срока хранения записи происходит перепланирование - например, если новая запись имеет наименьший expiry_time, отправка сообщения об удалении нектуальных данных отменяется и посылается новое сообшение с учетом этой записи.


Изменения первоначального каркаса приложения

1. В зависимости добавлена библиотека jason для удобного отображения данных запросов
2. Добавлен супервизор KVStore.Supervisor для отделения супервизора от приложения
3. Добавлены модули тестов
4. Добавлены конфиги для разных сред исполнения

**Запуск приложения**

iex -S mix

**Запуск тестов**

mix test

**REST API**

Добавление записи

`post "/" - json запрос с телом вида {"key": "key", "value": "value", "ttl": 100}
`

Удаление записи по ключу

`delete "/:key"`

Изменение значения записи по ключу

`post "/:key" - json запрос с телом вида {"value": "value"}`

Изменение времени жизни записи по ключу

`post "/set_ttl/:key" - json запрос с телом вида {"ttl": 100}`

Получение всех записей
`get "/"`

Получение записи по ключу

`get "/:key"`

Получение времени жизни записи по ключу

`get "/get_ttl/:key"`

