go build -trimpath -buildvcs=false -ldflags="-s -w -H windowsgui -buildid=" -o proxy.exe main.go
