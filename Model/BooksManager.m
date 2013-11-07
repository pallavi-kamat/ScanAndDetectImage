/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "BooksManager.h"
#import "ImagesManager.h"
#import "BooksManagerDelegateProtocol.h"
#import "BookDataParser.h"
#import <MediaPlayer/MediaPlayer.h>
#import "VideoViewController.h"
#define VIDEO @"http://www.youtube.com/watch?feature=player_embedded&v=EIeTTu8KtUg"
@implementation BooksManager

@synthesize cancelNetworkOperation, networkOperationInProgress;

#define BOOKSJSONURL @"https://ar.qualcomm.at/samples/cloudreco/json"

static BooksManager *sharedInstance = nil;

#pragma mark - Public

-(void)bookWithJSONFilename:(NSString *)jsonFilename withDelegate:(id <BooksManagerDelegateProtocol>)aDelegate forTrackableID:(const char *)trackableID
{
    networkOperationInProgress = YES;
   // NSLog(@"Track ID ******************** %s",trackableID);
    if (strcmp(trackableID, "bd450a2a56804016a2d548112ebcd73a")==0) {
        NSLog(@"Track ID ********************2");
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
    } else if (strcmp(trackableID, "9a208939d7d94e4a8b25dfba706bdcaf")==0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
        NSLog(@"Track ID ********************3");
    } else if (strcmp(trackableID, "4cc13b6b190548acb310ca69c52194e6")==0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
        //[self playVideo];
    } else if (strcmp(trackableID, "6e90ae05c6e74482b86f27ef62d03c47")==0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
       // [self playVideo];
    } else if(strcmp(trackableID, "56729bc459ba40c0a1745c7464634798")==0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
        //[self playVideo];
    } else if(strcmp(trackableID, "d42f6ba5cbe542f28dbe72bae59aee07")==0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
         //[self playVideo];
    } else if(strcmp(trackableID, "eb3ab62b21dd4d1bb68b3a03267620c1")==0) {
        //[self playVideo];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
    } else if(strcmp(trackableID, "0224e62fe31d4cfba7eab15ddfe50b7f")==0) {
        //[self playVideo];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
        /*UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Do you want to play video" message:@"" delegate:self cancelButtonTitle:@"NO" otherButtonTitles:@"YES", nil] autorelease];
        [alert show];*/
    }
    //  Get URL
    /*NSString *anURLString = [NSString stringWithFormat:@"%@/%@", BOOKSJSONURL, jsonFilename];
    NSURL *anURL = [NSURL URLWithString:anURLString];
    
    [self infoForBookAtURL:anURL withDelegate:aDelegate forTrackableID:trackableID];*/
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            
            break;
        case 1:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIDEO]];
            break;
        default:
            break;
    }
}

-(void)playVideo {
    /*MPMoviePlayerController *moviePlayerController = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:VIDEO]];
    //[self.view addSubview:moviePlayerController.view];
    moviePlayerController.fullscreen = YES;
    [moviePlayerController play];*/
    //[self presentModalViewController:(UIViewController *)moviePlayerController animated:YES];
    VideoViewController *videoViewController = [[VideoViewController alloc] initWithNibName:@"VideoViewController" bundle:nil withVideoUrl:VIDEO];
    [self presentModalViewController:videoViewController animated:YES];
}

-(void)infoForBookAtURL:(NSURL* )url withDelegate:(id <BooksManagerDelegateProtocol>)aDelegate forTrackableID:(const char*)trackable
{
    // Store the delegate
    delegate = aDelegate;
    [delegate retain];
    
    // Store the trackable ID
    thisTrackable = [[NSString alloc] initWithCString:trackable encoding:NSASCIIStringEncoding];
    
    // Download the book info
    [self asyncDownloadInfoForBookAtURL:url];
}

-(void)asyncDownloadInfoForBookAtURL:(NSURL *)url
{
    // Download the info for this book
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
    [request setHTTPMethod:@"GET"];
    
    // Do not start the network operation immediately
    NSURLConnection *aConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    
    // Use the run loop associated with the main thread
    [aConnection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    // Start the network operation
    [aConnection start];
}

-(void)addBadTargetId:(const char*)aTargetId
{
    NSString *tid = [NSString stringWithUTF8String:aTargetId];
    
    if (tid)
    {
        [badTargets addObject:tid];
    }
}

-(BOOL)isBadTarget:(const char*)aTargetId
{
    BOOL retVal = NO;
    NSString *tid = [NSString stringWithUTF8String:aTargetId];
    
    if (tid)
    {
        retVal = [badTargets containsObject:tid];
        
        if (retVal)
        {
            NSLog(@"#DEBUG bad target found");
        }
    }
    else
    {
        NSLog(@"#DEBUG error: could not convert const char * to NSString");
    }
    
    return retVal;
}

-(id)init
{
    self = [super init];
    if (self)
    {
        badTargets = [[NSMutableSet alloc] init];
    }
    return self;
}

+(BooksManager *)sharedInstance
{
	@synchronized(self)
    {
		if (sharedInstance == nil)
        {
			sharedInstance = [[self alloc] init];
		}
	}
	return sharedInstance;
}

-(BOOL)isNetworkOperationInProgress
{
    // The BooksManager or ImagesManager may have a network operation in
    // progress
    return networkOperationInProgress | [[ImagesManager sharedInstance] networkOperationInProgress] ? YES : NO;
}

-(void)cancelNetworkOperations:(BOOL)cancel
{
    // Set or clear the cancel flags, which will be checked in each network
    // callback
    
    // BooksManager (self)
    cancelNetworkOperation = cancel;
    
    // ImagesManager
    [[ImagesManager sharedInstance] setCancelNetworkOperation:cancel];
}

-(void)infoDownloadDidFinishWithBookData:(NSData *)bookData withConnection:(NSURLConnection *)connection
{
    Book *book = nil;
    
    if (bookData)
    {
        //  Given a NSData, parse the book to a dictionary and then convert it into a Book object
        NSError *anError = nil;
        NSDictionary *bookDictionary = nil;
        
        //  Find out on runtime if the device can use NSJSONSerialization (iOS5 or later)
        NSString *className = @"NSJSONSerialization";
        Class class = NSClassFromString(className);
        
        if (!class)
        {
            //  Use custom BookDataParser.
            //
            //  IMPORTANT: BookDataParser is written to parse data specific to the CloudReco
            //  sample application and is not designed to be used in other applications.
            
            bookDictionary = [BookDataParser parseData:bookData];
            NSLog(@"#DEBUG Using custom JSONBookParser");
        }
        else
        {
            //  Use native JSON parser, NSJSONSerialization
            bookDictionary = [NSJSONSerialization JSONObjectWithData: bookData
                                                             options: NSJSONReadingMutableContainers
                                                               error: &anError];
            NSLog(@"#DEBUG Using NSJSONSerialization");
        }

        
        if (!bookDictionary)
        {
            NSLog(@"#DEBUG Error parsing JSON: %@", anError);
        }
        else
        {
            book = [[[Book alloc] initWithDictionary:bookDictionary] autorelease];
        }
    }
    
    //  Inform the delegate that the request has completed
    [delegate infoRequestDidFinishForBook:book withTrackableID:[thisTrackable cStringUsingEncoding:NSASCIIStringEncoding] byCancelling:[self cancelNetworkOperation]];
    
    if (YES == [self cancelNetworkOperation])
    {
        // Inform the ImagesManager that the network operation has already been
        // cancelled (so its network operation will not be started and therefore
        // does not need to be cancelled)
        [self cancelNetworkOperations:NO];
    }
    
    // Release objects associated with the completed network operation
    [thisTrackable release];
    thisTrackable = nil;
    
    [delegate release];
    delegate = nil;
    
    [bookInfo release];
    bookInfo = nil;
    
    //  We don't need this connection reference anymore
    [connection release];
    
    networkOperationInProgress = NO;
}

#pragma mark NSURLConnectionDelegate
// *** These delegate methods are always called on the main thread ***
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self infoDownloadDidFinishWithBookData:nil withConnection:connection];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSData *bookData = nil;
    
    if (YES == [self cancelNetworkOperation])
    {
        // Cancel this connection
        [connection cancel];
    }
    else if (bookInfo)
    {
        bookData = [NSData dataWithData:bookInfo];
    }
    
    [self infoDownloadDidFinishWithBookData:bookData withConnection:connection];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (YES == [self cancelNetworkOperation])
    {
        // Cancel this connection
        [connection cancel];
        
        [self infoDownloadDidFinishWithBookData:nil withConnection:connection];
    }
    else
    {
        if (nil == bookInfo)
        {
            bookInfo = [[NSMutableData alloc] init];
        }

        [bookInfo appendData:data];
    }
}


#pragma mark Singleton overrides

+ (id)allocWithZone:(NSZone *)zone
{
    //  Overriding this method for singleton
    
	@synchronized(self)
    {
		if (sharedInstance == nil)
        {
			sharedInstance = [super allocWithZone:zone];
			return sharedInstance;
		}
	}
	return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    //  Overriding this method for singleton
	return self;
}

- (id)retain
{
    //  Overriding this method for singleton
    return self;
}

- (NSUInteger)retainCount
{
    //  Overriding this method for singleton
	return NSUIntegerMax;
}

- (oneway void)release
{
    //  Overriding this method for singleton
}

- (id)autorelease
{
    //  Overriding this method for singleton
	return self;
}


@end
