go build main.go -trimpath -buildvcs=false -ldflags="-s -w -H windowsgui -buildid=" -o proxy.exe
