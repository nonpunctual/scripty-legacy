#!/bin/bash

# This script decodes JWT strings.

if [ -n "$1" ]
then
    input="$1"
else
    printf 'Enter a JWT: '
    read -r input
fi

if [ "$(echo "$input" | tr -cd '.' | wc -c)" -ne 2 ]
then
    echo "Not a JWT (expected header.payload.signature)." >&2; exit 1
fi

echo "$input" | jq -R '
split(".") as [$h,$p,$s]
| ($h|@base64d|fromjson) as $header
| ($p|@base64d|fromjson) as $payload
| if ($payload|has("tier")) and ($payload|has("devices"))
then {
    sub: $payload.sub,
    tier: $payload.tier,
    devices: $payload.devices,
    created: ($payload.iat|todate),
    expires: ($payload.exp|todate),
    iss: $payload.iss,
    typ: $header.typ,
    alg: $header.alg,
    note: $payload.note
    }
else $header + ($payload
    | if has("iat") then .iat |= todate else . end
    | if has("exp") then .exp |= todate else . end
    | if has("nbf") then .nbf |= todate else . end
    )
end'
