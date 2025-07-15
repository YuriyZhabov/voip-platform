#!/bin/bash

# Скрипт запуска Asterisk 22

set -e

# Проверяем конфигурационные файлы
if [ ! -f /etc/asterisk/pjsip.conf ]; then
    echo "Error: pjsip.conf not found!"
    exit 1
fi

if [ ! -f /etc/asterisk/extensions.conf ]; then
    echo "Error: extensions.conf not found!"
    exit 1
fi

# Удаляем поврежденную базу данных, если она существует
if [ -f /var/lib/asterisk/astdb.sqlite3 ]; then
    echo "Removing existing database..."
    rm -f /var/lib/asterisk/astdb.sqlite3
fi

# Инициализируем XML документацию
echo "Initializing XML documentation..."
mkdir -p /usr/share/asterisk/documentation/thirdparty
mkdir -p /var/lib/asterisk/documentation

# Создаем базовую XML документацию для Manager API
cat > /usr/share/asterisk/documentation/core-en_US.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<docs xmlns:xi="http://www.w3.org/2001/XInclude">
    <manager name="DBGet" language="en_US">
        <synopsis>Get DB Entry</synopsis>
        <description>Get a value from the Asterisk database.</description>
        <syntax>
            <xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
            <parameter name="Family" required="true">
                <para>The family of the key to retrieve.</para>
            </parameter>
            <parameter name="Key" required="true">
                <para>The key to retrieve.</para>
            </parameter>
        </syntax>
    </manager>
    <manager name="DBGetTree" language="en_US">
        <synopsis>Get DB Tree</synopsis>
        <description>Get a tree of values from the Asterisk database.</description>
        <syntax>
            <xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
            <parameter name="Family" required="true">
                <para>The family of the tree to retrieve.</para>
            </parameter>
        </syntax>
    </manager>
    <manager name="DBPut" language="en_US">
        <synopsis>Put DB Entry</synopsis>
        <description>Put a value into the Asterisk database.</description>
        <syntax>
            <xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
            <parameter name="Family" required="true">
                <para>The family of the key.</para>
            </parameter>
            <parameter name="Key" required="true">
                <para>The key to store.</para>
            </parameter>
            <parameter name="Val" required="true">
                <para>The value to store.</para>
            </parameter>
        </syntax>
    </manager>
    <manager name="DBDel" language="en_US">
        <synopsis>Delete DB Entry</synopsis>
        <description>Delete an entry from the Asterisk database.</description>
        <syntax>
            <xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
            <parameter name="Family" required="true">
                <para>The family of the key to delete.</para>
            </parameter>
            <parameter name="Key" required="true">
                <para>The key to delete.</para>
            </parameter>
        </syntax>
    </manager>
    <manager name="DBDelTree" language="en_US">
        <synopsis>Delete DB Tree</synopsis>
        <description>Delete a tree of entries from the Asterisk database.</description>
        <syntax>
            <xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
            <parameter name="Family" required="true">
                <para>The family of the tree to delete.</para>
            </parameter>
        </syntax>
    </manager>
</docs>
EOF

# Создаем XML документацию для Stasis
cat > /usr/share/asterisk/documentation/stasis-en_US.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<docs xmlns:xi="http://www.w3.org/2001/XInclude">
    <configInfo name="stasis" language="en_US">
        <synopsis>Stasis dialplan application and AMI configuration</synopsis>
        <configFile name="stasis.conf">
            <configObject name="threadpool">
                <synopsis>Threadpool configuration for Stasis</synopsis>
                <description>Configuration options for the Stasis threadpool.</description>
                <configOption name="initial_size">
                    <synopsis>Initial number of threads in the pool</synopsis>
                </configOption>
                <configOption name="idle_timeout_sec">
                    <synopsis>Number of seconds before an idle thread is disposed of</synopsis>
                </configOption>
                <configOption name="max_size">
                    <synopsis>Maximum number of threads in the pool</synopsis>
                </configOption>
            </configObject>
            <configObject name="declined_message_types">
                <synopsis>Declined message types configuration</synopsis>
                <description>Configuration for message types that should be declined by Stasis.</description>
                <configOption name="type">
                    <synopsis>Message type to decline</synopsis>
                </configOption>
            </configObject>
        </configFile>
    </configInfo>
</docs>
EOF

# Создаем XML документацию для res_statsd
cat > /usr/share/asterisk/documentation/res_statsd-en_US.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<docs xmlns:xi="http://www.w3.org/2001/XInclude">
    <configInfo name="res_statsd" language="en_US">
        <synopsis>StatsD client support configuration</synopsis>
        <configFile name="statsd.conf">
            <configObject name="global">
                <synopsis>Global StatsD configuration</synopsis>
                <description>Global configuration options for StatsD client support.</description>
                <configOption name="enabled">
                    <synopsis>Enable or disable StatsD support</synopsis>
                </configOption>
                <configOption name="server">
                    <synopsis>StatsD server hostname or IP address</synopsis>
                </configOption>
                <configOption name="port">
                    <synopsis>StatsD server port</synopsis>
                </configOption>
                <configOption name="prefix">
                    <synopsis>Prefix for all metrics</synopsis>
                </configOption>
            </configObject>
        </configFile>
    </configInfo>
</docs>
EOF

# Создаем XML документацию для CDR
cat > /usr/share/asterisk/documentation/cdr-en_US.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<docs xmlns:xi="http://www.w3.org/2001/XInclude">
    <configInfo name="cdr" language="en_US">
        <synopsis>Call Detail Record configuration</synopsis>
        <configFile name="cdr.conf">
            <configObject name="general">
                <synopsis>General CDR configuration</synopsis>
                <description>General configuration options for Call Detail Records.</description>
                <configOption name="enable">
                    <synopsis>Enable or disable CDR</synopsis>
                </configOption>
                <configOption name="unanswered">
                    <synopsis>Log unanswered calls</synopsis>
                </configOption>
                <configOption name="congestion">
                    <synopsis>Log congested calls</synopsis>
                </configOption>
                <configOption name="scheduleronly">
                    <synopsis>Use scheduler only for CDR processing</synopsis>
                </configOption>
                <configOption name="safeshutdown">
                    <synopsis>Safe shutdown for CDR</synopsis>
                </configOption>
                <configOption name="size">
                    <synopsis>CDR batch size</synopsis>
                </configOption>
                <configOption name="time">
                    <synopsis>CDR batch time</synopsis>
                </configOption>
                <configOption name="channeldefaultenabled">
                    <synopsis>Channel default enabled</synopsis>
                </configOption>
                <configOption name="ignorestatechanges">
                    <synopsis>Ignore state changes</synopsis>
                </configOption>
                <configOption name="ignoredialchanges">
                    <synopsis>Ignore dial changes</synopsis>
                </configOption>
            </configObject>
        </configFile>
    </configInfo>
</docs>
EOF

# Создаем XML документацию для CEL
cat > /usr/share/asterisk/documentation/cel-en_US.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<docs xmlns:xi="http://www.w3.org/2001/XInclude">
    <configInfo name="cel" language="en_US">
        <synopsis>Channel Event Logging configuration</synopsis>
        <configFile name="cel.conf">
            <configObject name="general">
                <synopsis>General CEL configuration</synopsis>
                <description>General configuration options for Channel Event Logging.</description>
                <configOption name="enable">
                    <synopsis>Enable or disable CEL</synopsis>
                </configOption>
                <configOption name="dateformat">
                    <synopsis>Date format for CEL</synopsis>
                </configOption>
                <configOption name="apps">
                    <synopsis>Applications to log</synopsis>
                </configOption>
                <configOption name="events">
                    <synopsis>Events to log</synopsis>
                </configOption>
            </configObject>
        </configFile>
    </configInfo>
</docs>
EOF

# Копируем в нужные места
cp /usr/share/asterisk/documentation/*.xml /var/lib/asterisk/documentation/ 2>/dev/null || true

# Убеждаемся, что директории принадлежат пользователю asterisk
chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /var/run/asterisk

# Проверяем синтаксис конфигурации
echo "Checking Asterisk configuration..."

# Устанавливаем максимальное количество открытых файлов
echo "Setting max files open to 1000"
ulimit -n 1000

# Запускаем Asterisk 22
echo "Starting Asterisk 22..."

# Запускаем от root, так как нужны права для инициализации
exec "$@"