#!/bin/bash

state=1
if [[ $# -gt 0 ]]; then 
  state=$1
fi
cmd="curl --location --request POST 'http://192.168.86.235:49153/upnp/control/basicevent1' \
--header 'SOAPACTION: \"urn:Belkin:service:basicevent:1#SetBinaryState\"' \
--header 'Content-Type: text/xml; ' \
--header 'accept: \"\"' \
--data-raw '<?xml version=\"1.0\" encoding=\"utf-8\"?>
<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
    <s:Body>
        <u:SetBinaryState xmlns:u=\"urn:Belkin:service:basicevent:1\">
            <BinaryState>${state}</BinaryState>
        </u:SetBinaryState>
    </s:Body>
</s:Envelope>'"
echo "$cmd"
eval $cmd
