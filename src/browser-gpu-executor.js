import {
    BrowserGPUExecutor as CoreBrowserGPUExecutor,
    ExecutionError,
} from '@gasm-compiler/core/browser';

const BUFFER_USAGE = globalThis.GPUBufferUsage ?? {
    MAP_READ: 1,
    COPY_SRC: 4,
    COPY_DST: 8,
    STORAGE: 128,
};

const SHADER_STAGE = globalThis.GPUShaderStage ?? {
    COMPUTE: 4,
};

const MAP_MODE = globalThis.GPUMapMode ?? {
    READ: 1,
};

const TYPE_BYTES = 4;

function align4(byteLength) {
    return Math.max(4, Math.ceil(byteLength / 4) * 4);
}

function regionEnd(region) {
    return region ? region.byteOffset + region.byteLength : 0;
}

function validateRegion(name, region, memorySize) {
    if (!region) return null;
    const byteOffset = Number(region.byteOffset ?? 0);
    const byteLength = Number(region.byteLength ?? 0);
    if (!Number.isInteger(byteOffset) || !Number.isInteger(byteLength)) {
        throw new ExecutionError(`${name} region must use integer byteOffset and byteLength`, 'binding');
    }
    if (byteOffset < 0 || byteLength < 0) {
        throw new ExecutionError(`${name} region cannot use negative offsets or lengths`, 'binding');
    }
    if (byteOffset % 4 !== 0 || byteLength % 4 !== 0) {
        throw new ExecutionError(`${name} region must be 4-byte aligned`, 'binding');
    }
    if (byteOffset + byteLength > memorySize) {
        throw new ExecutionError(`${name} region exceeds the GPU memory buffer`, 'binding');
    }
    return { byteOffset, byteLength };
}


function typedArrayFor(type, length) {
    if (type === 'f32') return new Float32Array(length);
    if (type === 'i32') return new Int32Array(length);
    return new Uint32Array(length);
}

function copyMappedRange(mappedRange, byteLength) {
    const copy = new Uint8Array(byteLength);
    copy.set(new Uint8Array(mappedRange, 0, byteLength));
    return copy.buffer;
}

export class BrowserGPUExecutor extends CoreBrowserGPUExecutor {
    _animMemorySize = 0;
    _animLayout = null;
    _animOutputOffset = 0;
    _animOutputSize = 0;
    _animFrameIndex = 0;
    _animPipelinedSlots = [];
    _animPreviousPipelinedSlot = null;

    async prepareAnimation(
        wgslCode,
        initialData,
        inputType,
        outputSize,
        outputType,
        workgroupCount,
        entryPointOrOptions = 'main',
        maybeOptions = {},
    ) {
        const hasOptionsInEntryPointSlot = typeof entryPointOrOptions === 'object' && entryPointOrOptions !== null;
        const options = hasOptionsInEntryPointSlot ? entryPointOrOptions : maybeOptions;
        const entryPoint = hasOptionsInEntryPointSlot ? (options.entryPoint ?? 'main') : entryPointOrOptions;

        const requestedMemorySize = align4(Math.max(initialData.byteLength, outputSize));
        const requestedLayout = options.layout ?? {};
        const maxRegionEnd = Math.max(
            regionEnd(requestedLayout.inputs),
            regionEnd(requestedLayout.outputs),
            regionEnd(requestedLayout.state),
        );
        const memorySize = align4(Math.max(requestedMemorySize, maxRegionEnd));

        const layout = {
            inputs: validateRegion(
                'inputs',
                requestedLayout.inputs ?? { byteOffset: 0, byteLength: initialData.byteLength },
                memorySize,
            ),
            outputs: validateRegion(
                'outputs',
                requestedLayout.outputs ?? { byteOffset: 0, byteLength: outputSize },
                memorySize,
            ),
            state: validateRegion('state', requestedLayout.state, memorySize),
        };

        if (!layout.outputs || layout.outputs.byteLength === 0) {
            throw new ExecutionError('outputs region must have a positive byteLength', 'binding');
        }

        await this.ensureInitialized();

        let pipeline = this.pipelineCache.get(wgslCode);
        if (!pipeline) {
            const shaderModule = this.device.createShaderModule({ code: wgslCode, label: 'anim' });
            const compilationInfo = await shaderModule.getCompilationInfo?.();
            if (compilationInfo) {
                const errors = compilationInfo.messages.filter((message) => message.type === 'error');
                if (errors.length > 0) {
                    const details = errors
                        .map((message) => `${message.message} at line ${message.lineNum}:${message.linePos}`)
                        .join('; ');
                    throw new ExecutionError(`WGSL compilation failed: ${details}`, 'compilation');
                }
            }

            const bindGroupLayout = this.device.createBindGroupLayout({
                entries: [{ binding: 0, visibility: SHADER_STAGE.COMPUTE, buffer: { type: 'storage' } }],
            });
            pipeline = await this.device.createComputePipelineAsync({
                layout: this.device.createPipelineLayout({ bindGroupLayouts: [bindGroupLayout] }),
                compute: { module: shaderModule, entryPoint },
            });
            this.pipelineCache.set(wgslCode, pipeline);
        }

        this._animInputBuffer?.destroy?.();
        this._animStagingBuffer?.destroy?.();
        for (const slot of this._animPipelinedSlots) {
            slot.buffer.destroy();
        }

        this._animInputBuffer = this.device.createBuffer({
            label: 'anim_memory',
            size: memorySize,
            usage: BUFFER_USAGE.STORAGE | BUFFER_USAGE.COPY_DST | BUFFER_USAGE.COPY_SRC,
        });
        this.queue.writeBuffer(
            this._animInputBuffer,
            0,
            initialData.buffer,
            initialData.byteOffset,
            Math.min(initialData.byteLength, memorySize),
        );

        this._animBindGroup = this.device.createBindGroup({
            layout: pipeline.getBindGroupLayout(0),
            entries: [{ binding: 0, resource: { buffer: this._animInputBuffer } }],
        });

        const stagingSize = align4(layout.outputs.byteLength);
        this._animStagingBuffer = this.device.createBuffer({
            label: 'anim_staging',
            size: stagingSize,
            usage: BUFFER_USAGE.MAP_READ | BUFFER_USAGE.COPY_DST,
        });

        this._animInputSize = layout.inputs?.byteLength ?? 0;
        this._animPipeline = pipeline;
        this._animStagingSize = stagingSize;
        this._animResultBuffer = typedArrayFor(outputType, stagingSize / TYPE_BYTES);
        this._animResultType = outputType;
        this._animCopyU8Dst = new Uint8Array(this._animResultBuffer.buffer, 0, stagingSize);
        this._animWorkgroupCount = workgroupCount;
        this._animMemorySize = memorySize;
        this._animLayout = layout;
        this._animOutputOffset = layout.outputs.byteOffset;
        this._animOutputSize = layout.outputs.byteLength;
        this._animFrameIndex = 0;
        this._animPipelinedSlots = [];
        this._animPreviousPipelinedSlot = null;
    }

    async executeFrame(inputData, options = {}) {
        if (!this._animInputBuffer || !this._animPipeline || !this._animBindGroup || !this._animStagingBuffer) {
            throw new ExecutionError('Animation has not been prepared', 'dispatch');
        }

        if (options.pipelined) {
            return this.executeFramePipelined(inputData, options);
        }

        const inputRegion = this._animLayout?.inputs;
        if (inputRegion && inputRegion.byteLength > 0) {
            if (inputData.byteLength < inputRegion.byteLength) {
                throw new ExecutionError('executeFrame inputData is smaller than the configured inputs region', 'binding');
            }
            this.queue.writeBuffer(
                this._animInputBuffer,
                inputRegion.byteOffset,
                inputData.buffer,
                inputData.byteOffset,
                inputRegion.byteLength,
            );
        }

        const commandEncoder = this.device.createCommandEncoder();
        const pass = commandEncoder.beginComputePass();
        pass.setPipeline(this._animPipeline);
        pass.setBindGroup(0, this._animBindGroup);
        pass.dispatchWorkgroups(
            this._animWorkgroupCount[0],
            this._animWorkgroupCount[1],
            this._animWorkgroupCount[2],
        );
        pass.end();
        commandEncoder.copyBufferToBuffer(
            this._animInputBuffer,
            this._animOutputOffset,
            this._animStagingBuffer,
            0,
            this._animStagingSize,
        );
        this.queue.submit([commandEncoder.finish()]);

        await this._animStagingBuffer.mapAsync(MAP_MODE.READ, 0, this._animStagingSize);
        const mappedRange = this._animStagingBuffer.getMappedRange(0, this._animStagingSize);
        this._animCopyU8Dst.set(new Uint8Array(mappedRange, 0, this._animStagingSize));
        this._animStagingBuffer.unmap();
        return this._animResultBuffer;
    }

    async executeFramePipelined(inputData, options) {
        const previousSlot = this._animPreviousPipelinedSlot;
        const frameIndex = this._animFrameIndex++;
        const slot = this.getPipelinedSlot(options.readbackPoolSize ?? 3, frameIndex);

        const inputRegion = this._animLayout?.inputs;
        if (inputRegion && inputRegion.byteLength > 0) {
            if (inputData.byteLength < inputRegion.byteLength) {
                throw new ExecutionError('executeFrame inputData is smaller than the configured inputs region', 'binding');
            }
            this.queue.writeBuffer(
                this._animInputBuffer,
                inputRegion.byteOffset,
                inputData.buffer,
                inputData.byteOffset,
                inputRegion.byteLength,
            );
        }

        const commandEncoder = this.device.createCommandEncoder();
        const pass = commandEncoder.beginComputePass();
        pass.setPipeline(this._animPipeline);
        pass.setBindGroup(0, this._animBindGroup);
        pass.dispatchWorkgroups(
            this._animWorkgroupCount[0],
            this._animWorkgroupCount[1],
            this._animWorkgroupCount[2],
        );
        pass.end();
        commandEncoder.copyBufferToBuffer(
            this._animInputBuffer,
            this._animOutputOffset,
            slot.buffer,
            0,
            this._animStagingSize,
        );
        this.queue.submit([commandEncoder.finish()]);

        slot.frameIndex = frameIndex;
        slot.promise = slot.buffer.mapAsync(MAP_MODE.READ, 0, this._animStagingSize).then(() => {
            const mappedRange = slot.buffer.getMappedRange(0, this._animStagingSize);
            slot.copyU8Dst.set(new Uint8Array(mappedRange, 0, this._animStagingSize));
            slot.buffer.unmap();
            return { outputs: slot.resultBuffer, frameIndex: slot.frameIndex };
        });
        this._animPreviousPipelinedSlot = slot;

        if (!previousSlot) {
            return { outputs: null, frameIndex: -1 };
        }
        return previousSlot.promise;
    }

    getPipelinedSlot(poolSize, frameIndex) {
        const normalizedPoolSize = Math.max(2, Math.floor(poolSize));
        while (this._animPipelinedSlots.length < normalizedPoolSize) {
            this._animPipelinedSlots.push({
                buffer: this.device.createBuffer({
                    label: 'anim_pipelined_staging',
                    size: this._animStagingSize,
                    usage: BUFFER_USAGE.MAP_READ | BUFFER_USAGE.COPY_DST,
                }),
                resultBuffer: typedArrayFor(this._animResultType, this._animStagingSize / TYPE_BYTES),
                copyU8Dst: null,
                promise: Promise.resolve({ outputs: null, frameIndex: -1 }),
                frameIndex: -1,
            });
            const newSlot = this._animPipelinedSlots[this._animPipelinedSlots.length - 1];
            newSlot.copyU8Dst = new Uint8Array(newSlot.resultBuffer.buffer, 0, this._animStagingSize);
        }
        return this._animPipelinedSlots[frameIndex % normalizedPoolSize];
    }

    resetMemory() {
        this.writeMemory(0, new Uint8Array(this._animMemorySize));
    }

    writeMemory(byteOffset, data) {
        if (!this._animInputBuffer) {
            throw new ExecutionError('Animation has not been prepared', 'binding');
        }
        validateRegion('writeMemory', { byteOffset, byteLength: data.byteLength }, this._animMemorySize);
        this.queue.writeBuffer(this._animInputBuffer, byteOffset, data.buffer, data.byteOffset, data.byteLength);
    }

    async readMemory(byteOffset, byteLength, outputType = this._animResultType) {
        if (!this._animInputBuffer) {
            throw new ExecutionError('Animation has not been prepared', 'readback');
        }
        validateRegion('readMemory', { byteOffset, byteLength }, this._animMemorySize);

        const stagingSize = align4(byteLength);
        const stagingBuffer = this.device.createBuffer({
            label: 'memory_readback',
            size: stagingSize,
            usage: BUFFER_USAGE.MAP_READ | BUFFER_USAGE.COPY_DST,
        });

        const commandEncoder = this.device.createCommandEncoder();
        commandEncoder.copyBufferToBuffer(this._animInputBuffer, byteOffset, stagingBuffer, 0, stagingSize);
        this.queue.submit([commandEncoder.finish()]);

        let mapped = false;
        try {
            await stagingBuffer.mapAsync(MAP_MODE.READ, 0, stagingSize);
            mapped = true;
            const copiedBuffer = copyMappedRange(stagingBuffer.getMappedRange(0, stagingSize), stagingSize);
            if (outputType === 'f32') return new Float32Array(copiedBuffer);
            if (outputType === 'i32') return new Int32Array(copiedBuffer);
            return new Uint32Array(copiedBuffer);
        } finally {
            if (mapped) stagingBuffer.unmap();
            stagingBuffer.destroy();
        }
    }

    async destroy() {
        await Promise.allSettled(this._animPipelinedSlots.map((slot) => slot.promise));
        this._animInputBuffer?.destroy?.();
        this._animStagingBuffer?.destroy?.();
        for (const slot of this._animPipelinedSlots) {
            slot.buffer.destroy();
        }
        this._animInputBuffer = null;
        this._animStagingBuffer = null;
        this._animPipelinedSlots = [];
        this._animPreviousPipelinedSlot = null;
        await super.destroy();
    }
}