Идентификационное имя: берем логин из личного кабинета Novofon (Телефония → Пользователи АТС → Имя пользователя → Вкладка «‎ВАТС»). Для примера в инструкции используем 1234567.

SIP-сервер: sip.novofon.ru

Для начала нужно отредактировать файл sip.conf.

sip.conf

[general]

srvlookup=yes

[1234567]

host=sip.novofon.ru

insecure=invite,port

type=peer

fromdomain=sip.novofon.ru

disallow=all

allow=alaw

allow=ulaw

dtmfmode=auto

secret=password

defaultuser=1234567

trunkname=1234567

fromuser=1234567

callbackextension=1234567

context=novofon-in

qualify=400

directmedia=no

nat=force_rport,comedia

[101] ;внутренний номер Вашего астериска

secret=password

host=dynamic

type=friend

context=novofon-out

Следующим шагом станет настройка входящей и исходящей маршрутизации. Это делается в файле extensions.conf

extensions.conf

[novofon-in]

exten => 1234567,1, Dial(SIP/101) ; все входящие звонки с транка 1234567 направлены на внутренний номер 101

[novofon-out]

exten => _XXX,1,Dial(SIP/${EXTEN}) ; звонки на трехзначные внутренние номера Asterics

exten => _XXX.,1,Dial(SIP/${EXTEN}@1234567) ; звонки на номера в которых четыре и более цифр через транк 1234567

На этом стандартная настройка завершена.

Настройка через SIP URI
Этот метод настройки подходит в случае, при котором ваш сервер с Asterisk имеет “белый” IP-адрес.

В качестве примера ниже:

711111111111 – ваш виртуальный номер в сервисе Novofon;
1.11.111.11 – IP-адрес вашего сервера с Asterisk.
Для начала необходимо направить все звонки с виртуального номера на внешний сервер. Данные необходимо указать в формате 711111111111@1.11.111.11. Сделать это можно в личном кабинете, в разделе “Настройки”, страница “Виртуальный номер”.

Теперь внесем изменения в файл sip.conf

sip.conf

[novofon]

host=sip.novofon.ru

type=peer

insecure=port,invite

context=novofon-in

disallow=all

allow=alaw

allow=ulaw

dtmfmode = auto

directmedia=no

nat=force_rport,comedia

Входящий маршрут редактируем в файле extensions.conf

extensions.conf

[novofon-in]

exten => 711111111111,1, Dial(SIP/101)

Настройка завершена.

Назначение имени номеру.
Если в работе вы используете несколько номеров, то можете каждому задать свое имя и настроить входящую маршрутизацию по этому параметру.

Эта информация передается в параметре CALLERID(name). Предположим, что у вас два номера и вы дали им имена “moscow” и “saintpetersburg”. И в первом случае вы хотите направлять все вызовы на внутренний номер 101, а во втором на 102. Другие звонки нужно отклонять сигналом “занято”. В таком случае в файле extensions.conf пишем:

extensions.conf

[novofon-in]

exten => _X.,1,GotoIf($["${CALLERID(name)}" = "moscow"]?2:3)

exten => _X.,2,Dial(PJSIP/101)

exten => _X.,3,GotoIf($["${CALLERID(name)}" = "saintpetersburg"]?4:5)

exten => _X.,4,Dial(PJSIP/102)

exten => _X.,5,Busy

Управление маршрутизацией по номеру.
Если вам необходимо звонки с номера направлять на определенный внутренний номер, то вы можете задать его в хедере CALLED_DID. Например, звонки с номера 74951111111 вы хотите принимать на 101, а 78121111111 на 102 (а все прочие отклонять с сигналом “занято”), то вам необходимо указать следующую информацию в файле extensions.conf

extensions.conf

[novofon-in]

exten => _X.,1,GotoIf($["${PJSIP_HEADER(read,CALLED_DID)}" = "74951111111"]?2:3)

exten => _X.,2,Dial(PJSIP/101)

exten => _X.,3,GotoIf($["${PJSIP_HEADER(read,CALLED_DID)}" = "78121111111"]?4:5)

exten => _X.,4,Dial(PJSIP/102)

exten => _X.,5,Busy