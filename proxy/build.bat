go build -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -o proxy.exe main.go
