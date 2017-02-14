# SimpleRecorder
a simple Objective-C streaming audio recorder.

## Why SimpleRecorder?

When I was trying to implement an iOS app, I realized that there was something missing from the built-in libraries of Cocoa: a simple recorder that would return the audio stream and not just save a file (AVAudioRecordre), without needing to get your hands dirty (CoreAudio), so I coded up a suitable simple recorder and used it in my own project.

## How to use it

I may create a CocoaPod for it later, but until then you can simply copy and paste the files and use them. The class includes a delegate method which you have to implement. 

### Initialization

There are two initializers, one using a file URL, the second one using a file URL and an AudioStreamBasicDescription struct. In the case of the latter, you can control the configuaration of the audio being recorded, otherwise the default settings would be considered (16000 frequency, little-endian LinearPCM, 16 bit depth, mono). Just find a valid URL within your system and pass it to the initialiazor.

''' objc
// init
- (id) initWithAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd URL:(NSURL*) fileURL;
- (id) initWithFileURL: (NSURL*) fileURL;
'''

Then you would also have to set the instance's delegate to the class you're using it in:

'''objc
SimpleRecorder* SR = [[SimpleRecorder alloc] initWithFileURL: URL];
SR.delegate = self;
'''
and include the delegate in the class definition:
'''objc
@interface MyClass : UIViewController <SimpleRecorderDelegate>
'''
You're done.

### Capturing Audio

Implement the following delegate method inside your class:

'''objc
- (void) audioChunkRecorded: (SimpleRecorder*) SRecoder withRawData: (NSData*) data;
'''

It returns a NSData object every time a chunk is recorded.
