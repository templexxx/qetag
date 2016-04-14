package main

//THE ALGORITHM IS FROM HERE: https://github.com/qiniu/qetag
import (
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
	"io"
	"os"
	"runtime"
	"time"
)

const (
	BLOCK_BITS = 22
	BLOCK_SIZE = 1 << BLOCK_BITS //4MB
)

func blockSha1(r io.Reader, blockIndex int, c chan map[int][]byte) {
	sha1Bytes, _ := calcSha1(r, nil)
	c <- map[int][]byte{
		blockIndex: sha1Bytes,
	}
}

func calcSha1(r io.Reader, baseBytes []byte) (finalBytes []byte, err error) {
	h := sha1.New()
	_, cpErr := io.Copy(h, r)
	if cpErr != nil {
		err = cpErr
		return
	}
	finalBytes = h.Sum(baseBytes)
	return
}

func calcEtag(filePath string) (qetag string, err error) {
	fp, openErr := os.Open(filePath)
	if openErr != nil {
		err = openErr
		return
	}
	defer fp.Close()
	fstat, statErr := fp.Stat()
	if statErr != nil {
		err = statErr
		return
	}
	fSize := fstat.Size()

	if fSize <= BLOCK_SIZE {
		lReader := io.LimitReader(fp, BLOCK_SIZE)
		finalBytes := make([]byte, 0, 21)
		finalBytes = append(finalBytes, 0x16)
		finalBytes, cErr := calcSha1(lReader, finalBytes)
		if cErr != nil {
			err = cErr
			return
		}
		qetag = base64.URLEncoding.EncodeToString(finalBytes)
	} else {
		blockCnt := int(fSize / BLOCK_SIZE)
		if fSize%BLOCK_SIZE != 0 {
			blockCnt += 1
		}

		blocksChan := make(chan map[int][]byte, blockCnt)
		for blockIndex := 0; blockIndex < blockCnt; blockIndex++ {
			buffer := make([]byte, BLOCK_SIZE)
			lReader := io.LimitReader(fp, BLOCK_SIZE)
			readCnt, readErr := lReader.Read(buffer)
			if readErr != nil {
				if readErr == io.EOF {
					break
				} else {
					err = readErr
					return
				}
			}
			go blockSha1(bytes.NewReader(buffer[:readCnt]), blockIndex, blocksChan)
		}
		blockSha1Map := make(map[int][]byte, 0)
		for i := 0; i < blockCnt; i++ {
			eachChan := <-blocksChan
			for k, v := range eachChan {
				blockSha1Map[k] = v
			}

		}
		blockSha1Bytes := make([]byte, 0, blockCnt*20)
		for i := 0; i < blockCnt; i++ {
			blockSha1Bytes = append(blockSha1Bytes, blockSha1Map[i]...)
		}

		finalSha1Bytes := make([]byte, 0, 21)
		finalSha1Bytes = append(finalSha1Bytes, 0x96)
		finalSha1Bytes, _ = calcSha1(bytes.NewReader(blockSha1Bytes), finalSha1Bytes)
		qetag = base64.URLEncoding.EncodeToString(finalSha1Bytes)
	}
	return
}

func main() {
	ts := time.Now()
	runtime.GOMAXPROCS(runtime.NumCPU())
	args := os.Args
	if len(args) != 2 {
		fmt.Println("Usage: qetag <filepath>")
		return
	}

	filePath := args[1]
	qetag, err := calcEtag(filePath)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(qetag)
	time.Sleep(6000)
	duration := time.Since(ts)
	fmt.Println(duration.String())
}
