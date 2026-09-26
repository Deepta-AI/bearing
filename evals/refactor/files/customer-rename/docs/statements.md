# Monthly statements

At month end `(*billing.Store).WriteStatements` writes one JSON line per
active paying account. Finance's importer (a spreadsheet macro, owned by
finance) reads these lines and looks the keys up case-sensitively:

    {"Period":"2026-09","Client":{"client_id":"c_101","name":"Asha Stores","plan":"basic","active":true,"monthly_paise":49900},"AmountPaise":49900}

Changing a key means a coordinated change with finance.
