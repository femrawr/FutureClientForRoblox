local BLOCK_SIZE = 64
local CV_SIZE = 32
local EXTENDED_CV_SIZE = 64
local MAX_STACK_DEPTH = 64
local STACK_BUFFER_SIZE = MAX_STACK_DEPTH * CV_SIZE

local CHUNK_START = 0x01
local CHUNK_END = 0x02
local PARENT_FLAG = 0x04
local ROOT_FLAG = 0x08

local IV = {
    0x6a09e667, 0xbb67ae85,
    0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c,
    0x1f83d9ab, 0x5be0cd19
}

local HEX_CHARS = '0123456789abcdef'

local INITIAL_VECTORS = buffer.create(CV_SIZE) do
    for i, v in next, IV do
        buffer.writeu32(INITIAL_VECTORS, (i - 1) * 4, v)
    end
end

local ENCODE_LOOKUP = buffer.create(256 * 2) do
    for byte = 0, 255 do
        local combined = string.byte(HEX_CHARS, bit32.rshift(byte, 4) + 1) + bit32.lshift(string.byte(HEX_CHARS, byte % 16 + 1), 8)
        buffer.writeu16(ENCODE_LOOKUP, byte * 2, combined)
    end
end

local function compress(hash, message, counter, v14, v15, full)
    local hash00 = buffer.readu32(hash, 0)
    local hash01 = buffer.readu32(hash, 4)
    local hash02 = buffer.readu32(hash, 8)
    local hash03 = buffer.readu32(hash, 12)
    local hash04 = buffer.readu32(hash, 16)
    local hash05 = buffer.readu32(hash, 20)
    local hash06 = buffer.readu32(hash, 24)
    local hash07 = buffer.readu32(hash, 28)

    local v00, v01, v02, v03 = hash00, hash01, hash02, hash03
    local v04, v05, v06, v07 = hash04, hash05, hash06, hash07
    local v08, v09, v10, v11 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a

    local v12 = counter % (2 ^ 32)
    local v13 = (counter - v12) * (2 ^ -32)

    local m00 = buffer.readu32(message, 0)
    local m01 = buffer.readu32(message, 4)
    local m02 = buffer.readu32(message, 8)
    local m03 = buffer.readu32(message, 12)
    local m04 = buffer.readu32(message, 16)
    local m05 = buffer.readu32(message, 20)
    local m06 = buffer.readu32(message, 24)
    local m07 = buffer.readu32(message, 28)
    local m08 = buffer.readu32(message, 32)
    local m09 = buffer.readu32(message, 36)
    local m10 = buffer.readu32(message, 40)
    local m11 = buffer.readu32(message, 44)
    local m12 = buffer.readu32(message, 48)
    local m13 = buffer.readu32(message, 52)
    local m14 = buffer.readu32(message, 56)
    local m15 = buffer.readu32(message, 60)

    local temp
    for index = 1, 7 do
        v00 += v04 + m00; v12 = bit32.lrotate(bit32.bxor(v12, v00), 16)
        v08 += v12; v04 = bit32.lrotate(bit32.bxor(v04, v08), 20)
        v00 += v04 + m01; v12 = bit32.lrotate(bit32.bxor(v12, v00), 24)
        v08 += v12; v04 = bit32.lrotate(bit32.bxor(v04, v08), 25)

        v01 += v05 + m02; v13 = bit32.lrotate(bit32.bxor(v13, v01), 16)
        v09 += v13; v05 = bit32.lrotate(bit32.bxor(v05, v09), 20)
        v01 += v05 + m03; v13 = bit32.lrotate(bit32.bxor(v13, v01), 24)
        v09 += v13; v05 = bit32.lrotate(bit32.bxor(v05, v09), 25)

        v02 += v06 + m04; v14 = bit32.lrotate(bit32.bxor(v14, v02), 16)
        v10 += v14; v06 = bit32.lrotate(bit32.bxor(v06, v10), 20)
        v02 += v06 + m05; v14 = bit32.lrotate(bit32.bxor(v14, v02), 24)
        v10 += v14; v06 = bit32.lrotate(bit32.bxor(v06, v10), 25)

        v03 += v07 + m06; v15 = bit32.lrotate(bit32.bxor(v15, v03), 16)
        v11 += v15; v07 = bit32.lrotate(bit32.bxor(v07, v11), 20)
        v03 += v07 + m07; v15 = bit32.lrotate(bit32.bxor(v15, v03), 24)
        v11 += v15; v07 = bit32.lrotate(bit32.bxor(v07, v11), 25)

        v00 += v05 + m08; v15 = bit32.lrotate(bit32.bxor(v15, v00), 16)
        v10 += v15; v05 = bit32.lrotate(bit32.bxor(v05, v10), 20)
        v00 += v05 + m09; v15 = bit32.lrotate(bit32.bxor(v15, v00), 24)
        v10 += v15; v05 = bit32.lrotate(bit32.bxor(v05, v10), 25)

        v01 += v06 + m10; v12 = bit32.lrotate(bit32.bxor(v12, v01), 16)
        v11 += v12; v06 = bit32.lrotate(bit32.bxor(v06, v11), 20)
        v01 += v06 + m11; v12 = bit32.lrotate(bit32.bxor(v12, v01), 24)
        v11 += v12; v06 = bit32.lrotate(bit32.bxor(v06, v11), 25)

        v02 += v07 + m12; v13 = bit32.lrotate(bit32.bxor(v13, v02), 16)
        v08 += v13; v07 = bit32.lrotate(bit32.bxor(v07, v08), 20)
        v02 += v07 + m13; v13 = bit32.lrotate(bit32.bxor(v13, v02), 24)
        v08 += v13; v07 = bit32.lrotate(bit32.bxor(v07, v08), 25)

        v03 += v04 + m14; v14 = bit32.lrotate(bit32.bxor(v14, v03), 16)
        v09 += v14; v04 = bit32.lrotate(bit32.bxor(v04, v09), 20)
        v03 += v04 + m15; v14 = bit32.lrotate(bit32.bxor(v14, v03), 24)
        v09 += v14; v04 = bit32.lrotate(bit32.bxor(v04, v09), 25)

        if index ~= 7 then
            temp = m02; m02 = m03; m03 = m10; m10 = m12; m12 = m09
            m09 = m11; m11 = m05; m05 = m00; m00 = temp
            temp = m06; m06 = m04; m04 = m07; m07 = m13; m13 = m14
            m14 = m15; m15 = m08; m08 = m01; m01 = temp
        end
    end

    if full then
        local result = buffer.create(EXTENDED_CV_SIZE)
        buffer.writeu32(result, 0,  bit32.bxor(v00, v08))
        buffer.writeu32(result, 4,  bit32.bxor(v01, v09))
        buffer.writeu32(result, 8,  bit32.bxor(v02, v10))
        buffer.writeu32(result, 12, bit32.bxor(v03, v11))
        buffer.writeu32(result, 16, bit32.bxor(v04, v12))
        buffer.writeu32(result, 20, bit32.bxor(v05, v13))
        buffer.writeu32(result, 24, bit32.bxor(v06, v14))
        buffer.writeu32(result, 28, bit32.bxor(v07, v15))
        buffer.writeu32(result, 32, bit32.bxor(v08, hash00))
        buffer.writeu32(result, 36, bit32.bxor(v09, hash01))
        buffer.writeu32(result, 40, bit32.bxor(v10, hash02))
        buffer.writeu32(result, 44, bit32.bxor(v11, hash03))
        buffer.writeu32(result, 48, bit32.bxor(v12, hash04))
        buffer.writeu32(result, 52, bit32.bxor(v13, hash05))
        buffer.writeu32(result, 56, bit32.bxor(v14, hash06))
        buffer.writeu32(result, 60, bit32.bxor(v15, hash07))

        return result
    else
        local result = buffer.create(CV_SIZE)
        buffer.writeu32(result, 0,  bit32.bxor(v00, v08))
        buffer.writeu32(result, 4,  bit32.bxor(v01, v09))
        buffer.writeu32(result, 8,  bit32.bxor(v02, v10))
        buffer.writeu32(result, 12, bit32.bxor(v03, v11))
        buffer.writeu32(result, 16, bit32.bxor(v04, v12))
        buffer.writeu32(result, 20, bit32.bxor(v05, v13))
        buffer.writeu32(result, 24, bit32.bxor(v06, v14))
        buffer.writeu32(result, 28, bit32.bxor(v07, v15))

        return result
    end
end

return function(data)
    local realData = buffer.fromstring(data)
    local dataLength = buffer.len(realData)

    local stateCvs = buffer.create(STACK_BUFFER_SIZE)
    local stateCv = buffer.create(CV_SIZE)
    buffer.copy(stateCv, 0, INITIAL_VECTORS, 0, CV_SIZE)

    local stackSize = 0
    local stateCounter = 0
    local stateChunkNumber = 0
    local stateEndFlag = 0
    local stateStartFlag = CHUNK_START

    local blockBuffer = buffer.create(BLOCK_SIZE)
    local popCv = buffer.create(CV_SIZE)
    local mergeBlock = buffer.create(EXTENDED_CV_SIZE)
    local stackCv = buffer.create(CV_SIZE)
    local block = buffer.create(EXTENDED_CV_SIZE)

    for blockOffset = 0, dataLength - BLOCK_SIZE - 1, BLOCK_SIZE do
        buffer.copy(blockBuffer, 0, realData, blockOffset, BLOCK_SIZE)
        stateCv = compress(stateCv, blockBuffer, stateCounter, BLOCK_SIZE, stateStartFlag + stateEndFlag)

        stateStartFlag = 0
        stateChunkNumber += 1

        if stateChunkNumber == 15 then
            stateEndFlag = CHUNK_END
        elseif stateChunkNumber == 16 then
            local mergeCv = stateCv
            local mergeAmount = stateCounter + 1

            while mergeAmount % 2 == 0 do
                stackSize -= 1
                buffer.copy(popCv, 0, stateCvs, stackSize * CV_SIZE, CV_SIZE)

                buffer.copy(mergeBlock, 0, popCv, 0, CV_SIZE)
                buffer.copy(mergeBlock, CV_SIZE, mergeCv, 0, CV_SIZE)

                mergeCv = compress(INITIAL_VECTORS, mergeBlock, 0, BLOCK_SIZE, PARENT_FLAG)
                mergeAmount /= 2
            end

            buffer.copy(stateCvs, stackSize * CV_SIZE, mergeCv, 0, CV_SIZE)
            stackSize += 1

            buffer.copy(stateCv, 0, INITIAL_VECTORS, 0, CV_SIZE)

            stateStartFlag = CHUNK_START
            stateCounter += 1
            stateChunkNumber = 0
            stateEndFlag = 0
        end
    end

    local lastLength = dataLength == 0 and 0 or ((dataLength - 1) % BLOCK_SIZE + 1)
    local paddedMessage = buffer.create(BLOCK_SIZE)

    if lastLength > 0 then
        buffer.copy(paddedMessage, 0, realData, dataLength - lastLength, lastLength)
    end

    local outputCv
    local outputBlock
    local outputLength
    local outputFlags

    if stateCounter > 0 then
        local mergeCv = compress(stateCv, paddedMessage, stateCounter, lastLength, stateStartFlag + CHUNK_END)

        for index = stackSize, 2, -1 do
            buffer.copy(stackCv, 0, stateCvs, (index - 1) * CV_SIZE, CV_SIZE)
            buffer.copy(block, 0, stackCv, 0, CV_SIZE)
            buffer.copy(block, CV_SIZE, mergeCv, 0, CV_SIZE)

            mergeCv = compress(INITIAL_VECTORS, block, 0, BLOCK_SIZE, PARENT_FLAG)
        end

        local firstStackCv = buffer.create(CV_SIZE)
        buffer.copy(firstStackCv, 0, stateCvs, 0, CV_SIZE)

        outputBlock = buffer.create(EXTENDED_CV_SIZE)
        buffer.copy(outputBlock, 0, firstStackCv, 0, CV_SIZE)
        buffer.copy(outputBlock, CV_SIZE, mergeCv, 0, CV_SIZE)

        outputCv = INITIAL_VECTORS
        outputLength = BLOCK_SIZE
        outputFlags = ROOT_FLAG + PARENT_FLAG
    else
        outputCv = stateCv
        outputBlock = paddedMessage
        outputLength = lastLength
        outputFlags = stateStartFlag + CHUNK_END + ROOT_FLAG
    end

    local result = compress(outputCv, outputBlock, 0, outputLength, outputFlags, true)

    local hex = buffer.create(64)
    for index = 0, 31 do
        buffer.writeu16(hex, index * 2, buffer.readu16(ENCODE_LOOKUP, buffer.readu8(result, index) * 2))
    end

    return buffer.tostring(hex)
end
