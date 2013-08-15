#import <UIKit/UIKit.h>

/***
	
	SendToGoodReader SDK
	
	Version 1.0
	
	Copyright (c) 2013 Yuri Selukoff.
	All Rights Reserved.
	
	You are allowed to use this SDK free of charge in all your projects, commercial or not. You are NOT required to mention the use of this SDK in your credits, although you can freely do so if you wish. You are NOT required to get our written permission to use this SDK in your products, although we'd appreciate if you'd let us know in which apps you are using it. You are not allowed to alter, disassemble or reverse-engineer this SDK.
	
	The use of this SDK does not grant you any license for GoodReader app itself. The GoodReader app itself must be purchased and deployed separately by you and your customers in a usual manner (via the Apple's App Store or other eligible methods).
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
	CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
	INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
	OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
	CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
	SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
	SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
	USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
	OF SUCH DAMAGE.
	
***/

/***
	
	I. Introduction
	
	This SDK serves a simple purpose - transferring files and folders to GoodReader app for further viewing and editing. Optionally, a "Save Back" functionality can be provided by GoodReader, allowing you to receive, for example, an annotated PDF file back in your app.
	
	An Internet access is NOT required for the transfer to work on a device, so you and your customers don't have to worry about additional charges, bad connections and other issues of this nature.
	
	Should you have any questions regarding this SDK, go to
		http://www.goodreader.com/support/
	and enter the "SendToGoodReader SDK" in the subject line.
	
	
	II. Brief Methods Overview
	
	Methods you should USE:
		GoodReaderTransferClient class:
			+ sendFiles:transferDelegate:optionalResultCode: (main starting point for any outgoing file transfer)
			+ isGoodReaderAppInstalled
			+ isCurrentlySending
			+ isCurrentlyReceiving
			+ isCurrentlySendingOrReceiving
			+ cancelSendingOrReceivingWithoutNotifyingTheDelegate
			+ takeOverIncomingURLRequest:optionalSaveBackDelegate: (you MUST call this method from your app delegate's -application:openURL:sourceApplication:annotation: method)
	Methods you should IMPLEMENT:
		GoodReaderTransferClientDelegate protocol (implementing this entire protocol is optional):
			- didFinishSendingToGoodReaderWithResultCode: (optional method)
		GoodReaderSaveBackDelegate protocol (implementing this protocol is required only if you're expecting a save-back from GoodReader app):
			- willStartReceivingSaveBackFromGoodReader: (optional method)
			- saveBackProgressUpdate: (optional method)
			- didFinishReceivingSaveBackFromGoodReaderWithResultCode:receivedFilePath:saveBackTag: (required method)
	
	
	III. General Usage Notes
	
	Using this SDK is very simple:
	
	Step 1. Include this header file (SendToGoodReader.h) in your source code.
	
	Step 2. Link the provided library file (libSendToGoodReader.a) to your project. You can link the file by selecting your target in Xcode's Project window, selecting the "Build Phases" tab, expanding the "Link Binary With Libraries" section, and dragging-and-dropping the library file to the list of linked libraries.
	
	Step 3. Include a special URL scheme in your Info.plist file. The scheme is derived from your app's bundle ID, and takes the following form:
			<your app bundle ID>.sendtogr
		So if your app bundle ID is "com.example.myapp", then your app should respond to this URL scheme: "com.example.myapp.sendtogr"
		You can do this by including the CFBundleURLTypes field (or appending the existing one) in your Info.plist file:
			<key>CFBundleURLTypes</key>
			<array>
				<dict>
					<key>CFBundleURLName</key>
					<string>com.example.myapp.sendtogr</string>
					<key>CFBundleURLSchemes</key>
					<array>
						<string>com.example.myapp.sendtogr</string>
					</array>
				</dict>
				// your other URL schemes here
			</array>
	
	Step 4. Allow the SDK to intercept dedicated URL invocations, otherwise the SDK will not be able to properly communicate with GoodReader app. First, make sure that your app delegate implements the application:openURL:sourceApplication:annotation: method. Insert the intercepting code in the beginning of the method's implementation. A typical method implementation should look like this:
			-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
				{
				if([ GoodReaderTransferClient takeOverIncomingURLRequest:url optionalSaveBackDelegate:yourSaveBackDelegateOrNil ]) return YES;
				// your usual code here
				}
		Please note that it is extremely important to allow the SDK to take over certain URLs, even if you're not planning on receiving save-backs. In case if you're not interested in save-backs, simply pass nil as a save-back delegate.
	
	Step 5. Call the GoodReaderTransferClient's +sendFiles:transferDelegate:optionalResultCode: method to start the actual file transfer. See below for details.
	
	Step 6 (optional). Implement a transfer client delegate (passed to the SDK in Step 5) to receive a notification of either a success or a failure of the transfer. Useful if you're sending temporary files generated on-the-fly, and you need to know when it is safe to dispose of them. See below for details.
	
	Step 7 (optional). If you expect to receive a save-back from GoodReader, implement a save-back delegate. See below for details.
	
	Here's how a typical transfer (sending) works:
		- you call the sendFiles method. The method returns a success code, and it does it reasonably quickly, so it is safe to call it from the main thread. The actual transfer occurs later on a dedicated background thread.
		- the SDK launches GoodReader, your app is taken to the background
		- GoodReader displays a progress bar of the transfer process
		- the interface may occasionally flip back and forth between apps a few times, so if you're processing the applicationDidEnterBackground/applicationWillEnterForeground/applicationWillResignActive/applicationDidBecomeActive notifications, be prepared for several cycles of the flipping.
		- your app receives a transfer delegate notification when the transfer ends (with either a success or a failure code). This is where you should get rid of all your temporary files created for the transfer.
		- GoodReader app will stay in the foreground and present new files to the user
	
	Here's how a typical save-back (receiving) works:
		- the user presses the "Save Back" button in GoodReader app after making some changes in a file
		- your app gets launched, and takeOverIncomingURLRequest method intercepts that launch
		- your save-back delegate receives a willStartReceivingSaveBackFromGoodReader notification. This is a good time to start showing some progress UI.
		- the interface may occasionally flip back and forth between apps a few times, so if you're processing the applicationDidEnterBackground/applicationWillEnterForeground/applicationWillResignActive/applicationDidBecomeActive notifications, be prepared for several cycles of the flipping.
		- your save-back delegate optionally receives several saveBackProgressUpdate notifications. This will not happen for small files.
		- your save-back delegate receives a didFinishReceivingSaveBackFromGoodReaderWithResultCode notification. This is a good time to hide a progress UI and consume a file that has arrived.
		- your app stays in the foreground
	
	Normally you shouldn't display any progress UI when sending files to GoodReader, because your app will spend most of the time in the background. GoodReader will display the necessary progress bar of its own. However, when receiving a save-back, it is your app that will be in the foreground, so it can be useful to display some progress UI, although it is not required. Use various save-back delegate methods to determine what and when you should be displaying.
	
	Minimum iOS version required: iOS 4.3
	
	All delegate methods are called from the main thread, so you can freely update your user interface from within the delegate methods.
	
***/

/***
	Result codes provided by various methods and delegate notifications
***/
typedef enum {
	kGoodReaderTransferResult_Success = 0, /*** a particular operation (or the entire transfer) has finished successfully ***/
	kGoodReaderTransferResult_AppNotInstalled = 1, /*** either GoodReader app is not installed, or its version is too old (v.3.19.x is the required minimum for this feature) ***/
	kGoodReaderTransferResult_PrevTransferInProgress = 2, /*** the transfer didn't start, a previous transfer is still in progress ***/
	kGoodReaderTransferResult_InvalidParameter = 3, /*** the parameters passed to the library are either malformed or point to a non-existent file or folder ***/
	kGoodReaderTransferResult_OSError = 4, /*** some iOS error has occured, including memory allocation and source file read errors ***/
	kGoodReaderTransferResult_Timeout = 5, /*** GoodReader app didn't respond within a reasonable timeframe ***/
	kGoodReaderTransferResult_CommunicationError = 6, /*** communication with GoodReader app didn't go well, including a user cancellation ***/
	kGoodReaderTransferResult_DiskWriteError = 7 /*** error writing to disk when receiving a file being saved back from GoodReader ***/
	} GoodReaderTransferResultCodeEnum;

/***
	Various keys to be used when passing a parameters dictionary to the sendFiles method
***/
extern NSString *const kSendToGoodReader_ParamKey_ObjectToSend;
extern NSString *const kSendToGoodReader_ParamKey_SuggestedFileName;
extern NSString *const kSendToGoodReader_ParamKey_EstimatedSize;
extern NSString *const kSendToGoodReader_ParamKey_SaveBackTag;

/***
	Maximum size for the save-back tag (NSData object). Exceding this size will result in an error.
***/
const NSUInteger kSendToGoodReader_SaveBackTag_MaxSize = 4096;



/***
	This protocol is a delegate for the outgoing transfer process. Use it to get notified of the transfer's success or failure.
	Implementing this protocol is optional.
	All delegate methods are called from the main thread, so you can freely update your user interface from within the delegate methods.
***/
@protocol GoodReaderTransferClientDelegate <NSObject>
@optional
-(void)didFinishSendingToGoodReaderWithResultCode:(GoodReaderTransferResultCodeEnum)resultCode;
/***
	This delegate notification is called when the outgoing transfer is completely finished with either a success or a failure. Use the resultCode parameter to determine the result.
	This method is useful if you're using some temporary files for the transfer. When this notification arrives, it is safe to get rid of them.
	All delegate methods are called from the main thread, so you can freely update your user interface from within the delegate methods.
***/
@end



/***
	This protocol is a delegate for the save-back process. Use it to get notified when a file arrives, and to update the save-back progress UI.
	Implementing this protocol is required only if you're expecting a save-back from GoodReader app.
	All delegate methods are called from the main thread, so you can freely update your user interface from within the delegate methods.
***/
@protocol GoodReaderSaveBackDelegate <NSObject>

@optional

-(void)willStartReceivingSaveBackFromGoodReader:(UInt64)estimatedFileSize;
/***
	The incoming  transfer is about to begin, and you're about to receive a file of estimatedFileSize size. You can use the estimated size to display a progress bar.
	Implementing this method is optional.
	All delegate methods are called from the main thread, so you can freely update your user interface from within the delegate methods.
***/

-(void)saveBackProgressUpdate:(UInt64)totalBytesReceived;
/***
	As a save-back process is occuring, you may receive several progress update notifications. Use the provided totalBytesReceived value to display a progress bar.
	You will not receive this notification at all if a file being saved back is small enough.
	Implementing this method is optional.
	All delegate methods are called from the main thread, so you can freely update your user interface from within the delegate methods.
***/

@required

-(void)didFinishReceivingSaveBackFromGoodReaderWithResultCode:(GoodReaderTransferResultCodeEnum)resultCode receivedFilePath:(NSString *)receivedFilePath saveBackTag:(NSData *)saveBackTag;
/***
	This notification is sent when a save-back process is over, either successfully or not. If resultCode is kGoodReaderTransferResult_Success, then the receivedFilePath value will point to the received file. The file will be located in your app's tmp directory (as provided by an NSTemporaryDirectory function call). Once this notification arrives, you take the ownership of this file, and so this is your responsibility now to either move this file out of the tmp directory or to delete it. Don't keep files in tmp directory if you intend to use them - iOS may suddenly flush the entire tmp directory in low disk space situations.
	Use the provided saveBackTag to identify the original file that this saved back file corresponds to. The saveBackTag object will contain the same bytes that you've passed to the sendFiles method earlier.
	Implementing this method is required if you're expecting a save-back.
	All delegate methods are called from the main thread, so you can freely update your user interface from within the delegate methods.
***/

@end



/***
	This is the main operational class. Use its methods to start and to cancel the transfer, and also to obtain an information about the current transfer status.
	This class is not thread-safe. While its methods can be called from any thread, the result of calling these methods from different threads at the same time is undefined. None of this class's methods are blocking, therefore it is safe to call them from the main thread. The actual transfer will occur on a dedicated background thread.
***/
@interface GoodReaderTransferClient : NSObject

+(BOOL)isGoodReaderAppInstalled;
/***
	Returns YES if a proper version of GoodReader app is installed on the device. Returns NO if GoodReader app is either not installed, or its version is insufficient. This SDK requires GoodReader app v.3.19.x or later.
***/

+(BOOL)sendFiles:(id)filesAndFoldersToSend transferDelegate:(id <GoodReaderTransferClientDelegate>)transferDelegate optionalResultCode:(GoodReaderTransferResultCodeEnum *)optionalResultCode;
/***
	Call this method to start a transfer to GoodReader. Make sure that the files being transferred will stay intact until you receive a success or failure delegate notification.
	Sending the same file/folder to GoodReader several times will create several independent copies of this file/folder in GoodReader's sandbox.
	
	Parameters:
		
		filesAndFoldersToSend
			Required.
			This parameter may be an instance of NSString, NSInputStream, NSDictionary or NSArray.
			Pass an NSString to transfer a single file or folder without any additional parameters. The string is a file system path to a file/folder to be transferred.
			Pass an NSInputStream to transfer a single file without any additional parameters. A destination file name will be randomly chosen by GoodReader.
			Pass an NSDictionary to transfer a single file or folder with additional parameters (see below for a description of dictionary keys).
			Pass an NSArray of NSString, NSInputStream or NSDictionary objects to transfer several files/folders at once. It is safe to mix NSString, NSInputStream and NSDictionary objects in a single array.
			Should you choose to pass an NSDictionary object, use these dictionary keys:
				kSendToGoodReader_ParamKey_ObjectToSend
					Required.
					Either an NSString or an NSInputStream object. NSString is a file system path to a source file/folder. NSInputStream is a data source for a file. If the string path points to a non-existing file or folder, a kGoodReaderTransferResult_InvalidParameter error code will be returned.
					It is not guaranteed that the original file/folder name will be preserved in GoodReader's sandbox. If a target name already exists in GoodReader, GoodReader will alter the new incoming file/folder's name to create a new unique name.
				kSendToGoodReader_ParamKey_SuggestedFileName
					Optional.
					An NSString object.
					Will be used by GoodReader as a hint for a target file name. Especially useful if you're passing a source file as an NSInputStream.
					It is not guaranteed that this name will be preserved in GoodReader's sandbox. If a target name already exists in GoodReader, GoodReader will alter the new incoming file/folder's name to create a new unique name.
				kSendToGoodReader_ParamKey_EstimatedSize
					Optional.
					An NSNumber object with an "unsigned long long" value.
					This is used only for files passed by an NSInputStream and ignored for all other files and folders. This value has no influence on the actual transfer process, and is not required to be 100% accurate. Moreover, it can be omitted altogether. It is merely a hint for GoodReader to display the correct percentage of the transfer progress.
				kSendToGoodReader_ParamKey_SaveBackTag
					Optional.
					An NSData object that will be passed back to you as a part of the "Save Back" routine. Should be passed for files only, and will result in an error if passed for folders. Use this object as a tag to identify the file that will be saved back later from GoodReader in your app, because the file name is not guaranteed to be the same as the one that you've initially passed. In fact, the name is likely to be appended with a suffix like "annotated" or similar. Omit this object if you're not expecting a save-back for this file. There's a size limit for this object - kSendToGoodReader_SaveBackTag_MaxSize. Passing a larger object will result in an error. If you're encoding a file system path into an NSData tag to identify the source file later, please note that the actual path of a file may change before the edited file will be sent back to you. For example, a "sandbox" component of an absolute file path may change if your app gets updated via the App Store. Therefore the use of absolute file paths is discouraged. On the other hand, storing a relative, container-based path might be a good idea. An NSString could be easily converted into an NSData and back by using the NSKeyedArchiver/NSKeyedUnarchiver API.
			
		delegate
			Optional. Pass nil if you're not interested in delegate notifications. The library stores a weak pointer to the delegate, so it is your responsibility to ensure that the object is alive during the entire transfer session, i.e. either until you receive a delegate notification or you manually cancel the session.
			
		optionalResultCode
			Optional. Pass NULL if you're not interested in an error code.
		
	Return Value:
		Returns YES to indicate that your input parameters were accepted, GoodReader app seems to be installed on the device, your app will soon be taken to the background, and the transfer will begin shortly. From now on you should not delete or modify any files being transferred until you receive a delegate notification. If this method returns YES, it doesn't mean that the transfer was successful. It simply means that the transfer has successfully begun. You may still receive a failure notification later via a delegate callback.
		Returns NO on error. If the optionalResultCode parameter was provided, it will contain an error code. If you were trying to transfer temporary files, it is safe to delete them now. You will not be receivng any further delegate notifications if this method returns NO.
***/

+(BOOL)isCurrentlySending;
/***
	Returns YES if a previous outgoing transfer to GoodReader is not finished yet.
***/

+(BOOL)isCurrentlyReceiving;
/***
	Returns YES if some save-back is currently in progress.
***/

+(BOOL)isCurrentlySendingOrReceiving;
/***
	Returns YES if any transfer activity is happening - either a transfer to GoodReader, or a save-back from it.
***/

+(void)cancelSendingOrReceivingWithoutNotifyingTheDelegate;
/***
	Cancels any transfer activity (either a transfer to GoodReader, or a save-back from it). Neither of your delegates (transfer and save-back delegates) will get notified about this cancellation, so you'll have to properly clean up your temporary files and progress UI after calling this method.
***/

+(BOOL)takeOverIncomingURLRequest:(NSURL *)incomingURLRequest optionalSaveBackDelegate:(id <GoodReaderSaveBackDelegate>)optionalSaveBackDelegate;
/***
	This method MUST be called by you from within your app delegate's -application:openURL:sourceApplication:annotation: method, even if you're not expecting a save-back from GoodReader.
	A typical app delegate implementation should look like this:
		-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
			{
			if([ GoodReaderTransferClient takeOverIncomingURLRequest:url optionalSaveBackDelegate:yourSaveBackDelegateOrNil ]) return YES;
			// your usual code here
			}
	Provide an optionalSaveBackDelegate reference if you're expecting a save-back from GoodReader app. The library stores a weak pointer to the delegate, so it is your responsibility to ensure that the object is alive during the entire lifetime of the app, because a save-back notification can arrive unexpectedly at any time.
	Pass nil as an optionalSaveBackDelegate value if you're not interested in save-backs.
	This method returns YES if it consumes a provided URL invocation. If it returns YES, you shouldn't process this particular URL invocation any further.
***/

@end

