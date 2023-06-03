#! /bin/sh

RESOLVERS_LIST="v3/relays.md"

curl -qL https://github.com/jedisct1/dnscrypt-proxy/releases/download/2.1.3/dnscrypt-proxy-linux_x86_64-2.1.3.tar.gz | tar xzvf - || exit 1

CONFIG="/tmp/dnscrypt-proxy.toml"
TEST_SERVER="sdns://AQcAAAAAAAAADTUxLjE1LjEyMi4yNTAg6Q3ZfapcbHgiHKLF7QFoli0Ty1Vsz3RXs1RUbxUrwZAcMi5kbnNjcnlwdC1jZXJ0LnNjYWxld2F5LWFtcw"
DNSCRYPT_PROXY="linux-x86_64/dnscrypt-proxy"
PIDFILE="/tmp/dnscrypt-proxy.pid"

relaycheck() {
    stamp="$1"
    {
        echo 'listen_addresses = ["127.0.0.1:5300"]'
        echo 'server_names = ["test-server"]'
        echo '[static."test-server"]'
        echo "stamp = '${TEST_SERVER}'"
        echo '[anonymized_dns]'
        echo 'skip_incompatible = true'
        echo 'direct_cert_fallback = false'
        echo "routes = [ { server_name = '*', via = ['${stamp}'] } ]"
    } >"$CONFIG"

    $DNSCRYPT_PROXY -config "$CONFIG" -pidfile "$PIDFILE" -loglevel 3 &
    sleep 5
    retcode=0
    if ! $DNSCRYPT_PROXY -config "$CONFIG" -resolve "example.com" >/dev/null; then
        retcode=1
    fi
    kill $(cat "$PIDFILE")
    return $retcode
}

relay_name=""
while read line; do
    case "$line" in
    \#\#\ *)
        relay_name=$(echo "$line" | sed 's/^## *//')
        continue
        ;;
    sdns:*)
        if relaycheck "$line" 2>&1; then
            echo "pass: ${relay_name}"
        elif relaycheck "$line" 2>&1; then
            echo "pass: ${relay_name} (1 retry)"
        elif relaycheck "$line" 2>&1; then
            echo "pass: ${relay_name} (2 retries)"
        elif relaycheck "$line" 2>&1; then
            echo "pass: ${relay_name} (3 retries)"
        else
            echo "FAIL: ${relay_name} ($line)" >&2
        fi
        ;;
    esac
done <"$RESOLVERS_LIST"
