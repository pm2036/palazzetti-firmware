#!/usr/bin/lua

dofile "/etc/main.lib.lua"
dofile "/etc/maindef.lua"

FILE="/tmp/enroll.enc"

PAYLOAD="{\"mac\":\"" .. CBOXPARAMS["MAC"] .. "\"}"
CMD="curl -s --cacert /etc/cacerts.pem -XPOST -H 'x-api-key: " .. CBOXPARAMS["API-KEY"] .. "' -H \"Content-type: application/json\" -d '" .. PAYLOAD .. "' '" .. CBOXPARAMS["API-ENDPOINT"] .. "/thing" .. "' > " .. FILE
--print(CMD)
--eval $CMD
os.execute(CMD)

os.execute("openssl aes-256-cbc -d -K 3e444f292b506c7e2f4f2c6250514d5b4a7d4f273f757276512b394e6c574122 -iv 3e444f292b506c7e2f4f2c6250514d5b -in " .. FILE .. " -out " .. FILE .. ".dec")

os.execute("tar xvzf " .. FILE .. ".dec -C /etc/")

os.execute("rm " .. FILE .. "*")