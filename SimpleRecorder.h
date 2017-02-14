//
//  SimpleRecorder.h
//  testrecorder
//
//  Created by pro on 11/24/1395 AP.
//  Copyright © 1395 pro. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol SimpleRecorderDelegate;

@interface SimpleRecorder : NSObject {
    
// private recorder objects
@private
AudioStreamBasicDescription		mDataFormat;
AudioQueueRef					mQueue;
AudioQueueBufferRef				mBuffers[3];
AudioFileID						mAudioFile;
UInt32							mBufferByteSize;
SInt64							mCurrentPacket;
}

// class properties
@property (weak, nonatomic) id <SimpleRecorderDelegate> delegate;
@property (nonatomic) BOOL isRunning;
@property (nonatomic) BOOL enableMetering;
@property (nonatomic) float latestAveragePowerInDecibels;
@property (strong,nonatomic) NSURL* audioFileURL;

// init
- (id) initWithAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd URL:(NSURL*) fileURL;
- (id) initWithFileURL: (NSURL*) fileURL;

// methods
- (void) prepare;
- (void) start;
- (void) stop;

@end

// the protocol
@protocol SimpleRecorderDelegate <NSObject>
@required
- (void) audioChunkRecorded: (SimpleRecorder*) SRecoder withRawData: (NSData*) data;

@optional
- (void) audioRecordingFinished: (SimpleRecorder*) SRecorder successfully: (BOOL)flag withOSStatus: (OSStatus) status;
- (void) audioRecordingStarted: (SimpleRecorder*) SRecorder successfully: (BOOL) flag withOSStatus: (OSStatus) status;
@end

