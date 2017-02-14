//
//  SimpleRecorder.m
//  testrecorder
//
//  Created by pro on 11/24/1395 AP.
//  Copyright © 1395 pro. All rights reserved.
//

#import "SimpleRecorder.h"

@implementation SimpleRecorder
// with given settings
- (id)initWithAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd URL:(NSURL *)fileURL {
    self = [super init];
    mDataFormat = asbd;
    self.audioFileURL = fileURL;
    return self;
}

// use the default settings
- (id) initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    [self setDefaultFormat];
    self.audioFileURL = fileURL;
    return self;
}

- (void) prepare {
    [self rmConfigureOutputFile:(CFURLRef)self.audioFileURL];
}

- (void) start {
    [self prepare];
    OSStatus	error = noErr;
    mCurrentPacket = 0;
    self.isRunning = YES;
    error = AudioQueueStart(mQueue, NULL);
    
    if(error != noErr)
        [self.delegate audioRecordingStarted:self successfully:NO withOSStatus:error];
    else
        [self.delegate audioRecordingStarted:self successfully:YES withOSStatus:error];
}

- (void) stop {
    self.isRunning = NO;
    OSStatus	error = noErr;
    error = AudioQueueStop(mQueue, true);
    
    if(error != noErr) {
        NSLog(@"[SimpleRecorder] AudioQueueStop failed");
        [self.delegate audioRecordingFinished:self successfully:NO withOSStatus:error];
    }
    else
        [self.delegate audioRecordingFinished:self successfully:YES withOSStatus:error];
    
    error = AudioQueueDispose(mQueue, true);
    if(error != noErr) {
        NSLog(@"[SimpleRecorder] AudioQueueDispose failed");
    }
    AudioFileClose(mAudioFile);
}

// set up the default AudioStreamBasicDescription
- (void) setDefaultFormat{
    mDataFormat.mFormatID = kAudioFormatLinearPCM;															//	2
    mDataFormat.mSampleRate = 16000.0; //44100.0;																		//	3
    mDataFormat.mChannelsPerFrame = 1; //2;																		//	4
    mDataFormat.mBitsPerChannel = 16;																		//	5
    mDataFormat.mBytesPerPacket = mDataFormat.mChannelsPerFrame *sizeof(SInt16);							//	6
    mDataFormat.mBytesPerFrame = mDataFormat.mChannelsPerFrame *sizeof(SInt16);								//	6
    mDataFormat.mFramesPerPacket = 1;																		//	7
    mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger
    | kLinearPCMFormatFlagIsPacked;																			//	9
    self.isRunning = NO;
    
}

- (BOOL)rmConfigureOutputFile:(CFURLRef)inURL
{
    
    AudioFileTypeID		fileType = kAudioFileCAFType;
    OSStatus	error = noErr;
    
    
    //	Create a Recording Audio Queue
    error = AudioQueueNewInput (																			//	1
                                &mDataFormat,																//	2
                                HandleInputBuffer,															//	3
                                (__bridge void *)(self),																		//	4
                                NULL,																		//	5
                                kCFRunLoopCommonModes,														//	6
                                0,																			//	7
                                &mQueue																		//	8
                                );
    if(error != noErr) {
        NSLog(@"[SimpleRecorder] AudioQueueNewInput failed");
    }
    //	Getting the Full Audio Format from an Audio Queue
    UInt32 dataFormatSize = sizeof (mDataFormat);														//	1
    error = AudioQueueGetProperty (																		//	2
                                   mQueue,																//	3
                                   kAudioConverterCurrentOutputStreamDescription,						//	4
                                   &mDataFormat,														//	5
                                   &dataFormatSize														//	6
                                   );
    if(error != noErr) {
        NSLog(@"[SimpleRecorder] AudioQueueGetProperty failed");
    }
    //	Create an Audio File
    error = AudioFileCreateWithURL (
                                    inURL,																//	7
                                    fileType,															//	8
                                    &mDataFormat,														//	9
                                    kAudioFileFlags_EraseFile,											//	10
                                    &mAudioFile															//	11
                                    );
    if(error != noErr) {
        NSLog(@"[SimpleRecorder] AudioFileCreateWithURL failed");
    }
    
    
    // copy the cookie first to give the file object as much info as we can about the data going in
    error = [self rmSetMagicCookieForFile:mQueue audioFile:mAudioFile];
    if(error != noErr) {
        NSLog(@"[SimpleRecorder] rmSetMagicCookieForFile failed");
    }
    
    
    static const int maxBufferSize = 0x50000;																//	5
    int maxPacketSize = mDataFormat.mBytesPerPacket;														//	6
    
    if (maxPacketSize == 0)	{																				//	7
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (
                               mQueue,
                               kAudioConverterPropertyMaximumOutputPacketSize,
                               &maxPacketSize,
                               &maxVBRPacketSize
                               );
    }
    Float64	seconds = 0.1;
    Float64	numBytesForTime = mDataFormat.mSampleRate * maxPacketSize * seconds;							//	8
    mBufferByteSize  = (numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);					//	9
    
    // metering
    if (self.enableMetering) {
        UInt32 on = 1;
        AudioQueueSetProperty(mQueue,kAudioQueueProperty_EnableLevelMetering,&on,sizeof(on));
    }
    
    //	Prepare a Set of Audio Queue Buffers
    for (int i = 0; i < 3; ++i)
    {																									//	1
        error = AudioQueueAllocateBuffer (																//	2
                                          mQueue,														//	3
                                          mBufferByteSize,												//	4
                                          &mBuffers[i]													//	5
                                          );
        if(error != noErr) {
            NSLog(@"[SimpleRecorder] AudioQueueAllocateBuffer1 failed");
        }
        
        error = AudioQueueEnqueueBuffer (																//	6
                                         mQueue,														//	7
                                         mBuffers[i],													//	8
                                         0,																//	9
                                         NULL															//	10
                                         );
        if(error != noErr) {
            NSLog(@"[SimpleRecorder] AudioQueueAllocateBuffer2 failed");
        }
    }
    return YES;
}


static void HandleInputBuffer (
                               void *								aqData,
                               AudioQueueRef						inAQ,
                               AudioQueueBufferRef					inBuffer,
                               const AudioTimeStamp *				inStartTime,
                               UInt32								inNumPackets,
                               const AudioStreamPacketDescription *	inPacketDesc
                               )
{
    
    SimpleRecorder *recorder = (__bridge SimpleRecorder *)aqData;
    //	1
    if(inNumPackets == 0 && recorder->mDataFormat.mBytesPerPacket != 0)
        inNumPackets = inBuffer->mAudioDataByteSize / recorder->mDataFormat.mBytesPerPacket;
    
    // init data
    NSData* audioData = [NSData dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
    
    // calling delegate method
    [recorder.delegate audioChunkRecorded:recorder withRawData:audioData];
    
    if (recorder.enableMetering) {
        AudioQueueLevelMeterState meters[1], *pointer;
        UInt32 dlen = sizeof(meters);
        pointer = meters;
        AudioQueueGetProperty(inAQ, kAudioQueueProperty_CurrentLevelMeterDB, meters, &dlen);
        recorder.latestAveragePowerInDecibels = meters[0].mAveragePower;
    }

    if(AudioFileWritePackets(recorder->mAudioFile, false, inBuffer->mAudioDataByteSize, inPacketDesc,
                             recorder->mCurrentPacket, &inNumPackets, inBuffer->mAudioData) == noErr) {
        recorder->mCurrentPacket += inNumPackets;
        if(recorder.isRunning == YES) {
            OSStatus error = AudioQueueEnqueueBuffer(recorder->mQueue, inBuffer, 0, NULL);
            if(error != noErr) {
                NSLog(@"AudioQueueEnqueueBuffer failed");
            }
        }
    }
}


- (OSStatus)rmSetMagicCookieForFile:(AudioQueueRef) inQueue															//	1
                          audioFile:(AudioFileID)	inFile															//	2
{
    NSLog(@"rmSetMagicCookieForFile start");
    OSStatus	result = noErr;
    UInt32		cookieSize;
    if(AudioQueueGetPropertySize(inQueue, kAudioQueueProperty_MagicCookie, &cookieSize) == noErr)
    {
        char *	magicCookie = (char *) malloc(cookieSize);
        if(AudioQueueGetProperty(inQueue, kAudioQueueProperty_MagicCookie, magicCookie, &cookieSize) == noErr) {
            result = AudioFileSetProperty(inFile, kAudioFilePropertyMagicCookieData, cookieSize, magicCookie);
        }
        free (magicCookie);
    }
    return result;
}

@end
