#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
extern UIViewController* UnityGetGLViewController();

// Credit: https://github.com/ChrisMaire/unity-native-sharing

// Credit: https://stackoverflow.com/a/29916845/2373034
@interface UNativeShareEmailItemProvider : NSObject <UIActivityItemSource>
@property (nonatomic, strong) NSString *subject;
@property (nonatomic, strong) NSString *body;
@end

// Credit: https://stackoverflow.com/a/29916845/2373034
@implementation UNativeShareEmailItemProvider
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
	return [self body];
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
	return [self body];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType
{
	return [self subject];
}
@end

extern "C" void _NativeShare_Share( const char* files[], int filesCount, const char* subject, const char* text, const char* link ) 
{
	NSMutableArray *items = [NSMutableArray new];
	
	// When there is a subject, text is provided together with subject via a UNativeShareEmailItemProvider
	// Credit: https://stackoverflow.com/a/29916845/2373034
	if( strlen( subject ) > 0 )
	{
		UNativeShareEmailItemProvider *emailItem = [UNativeShareEmailItemProvider new];
		emailItem.subject = [NSString stringWithUTF8String:subject];
		emailItem.body = [NSString stringWithUTF8String:text];
		
		[items addObject:emailItem];
	}
	else if( strlen( text ) > 0 )
		[items addObject:[NSString stringWithUTF8String:text]];
	
	// Credit: https://forum.unity.com/threads/native-share-for-android-ios-open-source.519865/page-13#post-6942362
	if( strlen( link ) > 0 )
	{
		NSString *urlRaw = [NSString stringWithUTF8String:link];
		NSURLComponents *components = [NSURLComponents componentsWithString:urlRaw];
		NSURL *url = components.URL;
		if( url == nil )
		{
			// Try escaping the URL (including query/fragment)
			NSString *encodedUrl = [urlRaw stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
			if( encodedUrl != nil )
			{
				components = [NSURLComponents componentsWithString:encodedUrl];
				url = components.URL;
				if( url == nil )
					url = [NSURL URLWithString:encodedUrl];
			}
		}
		
		if( url != nil )
			[items addObject:url];
		else
			NSLog( @"Couldn't create a URL from link: %@", urlRaw );
	}
	
	for( int i = 0; i < filesCount; i++ ) 
	{
		NSString *filePath = [NSString stringWithUTF8String:files[i]];
		NSURL *fileURL = [NSURL fileURLWithPath:filePath];
		if( fileURL != nil )
			[items addObject:fileURL];
	}
	
	if( strlen( subject ) == 0 && [items count] == 0 )
	{
		NSLog( @"Share canceled because there is nothing to share..." );
		UnitySendMessage( "NSShareResultCallbackiOS", "OnShareCompleted", "2" );
		
		return;
	}
	
	UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
	
	void (^shareResultCallback)(UIActivityType activityType, BOOL completed, UIActivityViewController *activityReference) = ^void( UIActivityType activityType, BOOL completed, UIActivityViewController *activityReference )
	{
		NSLog( @"Shared to %@ with result: %d", activityType, completed );
		
		if( activityReference )
		{
			const char *resultMessage = [[NSString stringWithFormat:@"%d%@", completed ? 1 : 2, activityType] UTF8String];
			char *result = (char*) malloc( strlen( resultMessage ) + 1 );
			strcpy( result, resultMessage );
			
			UnitySendMessage( "NSShareResultCallbackiOS", "OnShareCompleted", result );
			free( result );
			
			// On iPhones, the share sheet isn't dismissed automatically when share operation is canceled, do that manually here
			if( !completed && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone )
				[activityReference dismissViewControllerAnimated:NO completion:nil];
		}
		else
			NSLog( @"Share result callback is invoked multiple times!" );
	};
	
	__block UIActivityViewController *activityReference = activity; // About __block usage: https://gist.github.com/HawkingOuYang/b2c9783c75f929b5580c
	activity.completionWithItemsHandler = ^( UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError )
	{
		if( activityError != nil )
			NSLog( @"Share error: %@", activityError );
		
		shareResultCallback( activityType, completed, activityReference );
		activityReference = nil;
	};
	
	UIViewController *rootViewController = UnityGetGLViewController();
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ) // iPhone
	{
		[rootViewController presentViewController:activity animated:YES completion:nil];
	}
	else // iPad
	{
		activity.modalPresentationStyle = UIModalPresentationPopover;
		UIPopoverPresentationController *popover = activity.popoverPresentationController;
		if( popover != nil )
		{
			popover.sourceView = rootViewController.view;
			CGRect bounds = rootViewController.view.bounds;
			popover.sourceRect = CGRectMake( CGRectGetMidX( bounds ), CGRectGetMidY( bounds ), 1, 1 );
		}

		[rootViewController presentViewController:activity animated:YES completion:nil];
	}
}
