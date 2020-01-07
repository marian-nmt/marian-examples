#!/bin/bash -v

wget 'https://mariannmt.blob.core.windows.net/marian/wngt2019/azcopy.tgz'
tar -xzf azcopy.tgz

./azcopy/azcopy copy 'https://mariannmt.blob.core.windows.net/marian/wngt2019/data.tgz' .
tar -xzf data.tgz

