package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

var toCopy = []string{
	"assets",
	"src",
	"games.json",
	"version.json",
}

type config struct {
	ExecutorPath string `json:"executor_path"`
}

func main() {
	args := os.Args[1:]
	if len(args) > 1 {
		fmt.Println("[!] you need to provide an action: build or clean")
		return
	}

	execPath, _ := os.Executable()
	configPath := filepath.Join(execPath, "..", "config.json")

	file, err := os.Open(configPath)
	if err != nil {
		fmt.Printf("[!] failed to open config file - %v", err)
		return
	}

	defer file.Close()

	var config config

	err = json.NewDecoder(file).Decode(&config)
	if err != nil {
		fmt.Printf("[!] failed to decode config - %v", err)
		return
	}

	executorPath := os.ExpandEnv(config.ExecutorPath)

	_, err = os.Stat(executorPath)
	if os.IsNotExist(err) {
		fmt.Println("[!] the executor path in the config does not exist")
		return
	}

	futureClientPath := filepath.Join(executorPath, "workspace", "FutureClientForRoblox")

	switch args[0] {
	case "b", "build":
		err := os.MkdirAll(futureClientPath, 0666)
		if err != nil {
			fmt.Printf("[!] failed to create future client folder - %v", err)
			return
		}

		srcFolderPath := filepath.Join(execPath, "..", "..")

		err = copyFiles(srcFolderPath, futureClientPath, toCopy)
		if err != nil {
			fmt.Printf("[!] failed to copy files to future client folder - %v", err)
			return
		}

		fmt.Println("[*] successfully copied files")
	case "c", "clean", "cleanup":
		_, err = os.Stat(futureClientPath)
		if os.IsNotExist(err) {
			fmt.Println("[!] future client folder not found, nothing to clean")
			return
		}

		err = os.RemoveAll(futureClientPath)
		if err != nil {
			fmt.Printf("[!] failed to remove future client folder from executor workspace - %v", err)
			return
		}

		fmt.Println("[*] successfully removed files")
	default:
		fmt.Println("[!] invalid argument")
	}
}

func copyFiles(srcPath string, dstPath string, whitelist []string) error {
	err := os.MkdirAll(dstPath, 0666)
	if err != nil {
		return err
	}

	for _, name := range whitelist {
		src := filepath.Join(srcPath, name)
		dst := filepath.Join(dstPath, name)

		var err error

		info, err := os.Stat(src)
		if err != nil {
			return err
		}

		if info.IsDir() {
			err = os.CopyFS(dst, os.DirFS(src))
		} else {
			err = copyFile(src, dst)
		}

		if err != nil {
			return err
		}
	}

	return nil
}

func copyFile(srcPath string, dstPath string) error {
	src, err := os.Open(srcPath)
	if err != nil {
		return err
	}

	defer src.Close()

	dst, err := os.Create(dstPath)
	if err != nil {
		return err
	}

	defer dst.Close()

	_, err = io.Copy(dst, src)
	return err
}
