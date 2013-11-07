/*==============================================================================
Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
All Rights Reserved.
Qualcomm Confidential and Proprietary
==============================================================================*/

#import <AVFoundation/AVFoundation.h>
#import <QCAR/QCAR.h>
#import <QCAR/CameraDevice.h>
#import "CROverlayViewController.h"
#import "OverlayView.h"
#import "QCARutils.h"
#import "QCARHelper.h"
#import "BooksManager.h"
#import "TargetOverlayView.h"
#import "CRQCARutils.h"
#import "ARViewController.h"
#import "EAGLView.h"
#import "BookWebDetailViewController.h"
#import "ImagesManager.h"

@interface CROverlayViewController()
- (void)centerViewInFrame;
@end

@implementation CROverlayViewController

@synthesize targetOverlayView;
@synthesize arViewController;

#pragma mark - Private

- (void) addLoadingView
{
    //  Adds basic spining wheel that appears every time the user scans a book
    
    float loadingViewWidth = 100;
    float loadingViewHeight = 100;
    
    //  Initiate loadingView
    loadingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, loadingViewWidth, loadingViewHeight)];
    loadingView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    loadingView.layer.cornerRadius = 10;
    
    //  Initiate activity indicator
    UIActivityIndicatorView *anActivityIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
    [anActivityIndicator startAnimating];
    anActivityIndicator.center = loadingView.center;
    [loadingView addSubview:anActivityIndicator];
    
    loadingView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin |
                                    UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin;
    
    //  Add loading view to the overlay view
    loadingView.center = self.view.center;
    
    [self.view addSubview:loadingView];
}

- (void)removeBookFromScreen
{
    closeButton.hidden = YES;
    
    [self.targetOverlayView setHidden:YES];
    
    [(CRViewController *) arViewController enterScanningMode];

    [CRQCARutils getInstance].lastScannedBook = nil;
    [CRQCARutils getInstance].lastTargetIDScanned = nil;
}

- (void)centerViewInFrame
{
    CGFloat containerWidth = self.view.frame.size.width;
    CGFloat containerHeight = self.view.frame.size.height;
        
    CGRect newFrame = CGRectMake((containerWidth - targetOverlayView.frame.size.width) / 2,
                                (containerHeight - targetOverlayView.frame.size.height) / 2,
                                targetOverlayView.frame.size.width,
                                targetOverlayView.frame.size.height);
    
    self.targetOverlayView.frame = newFrame;
}

- (void) refreshStatusLabel:(NSTimer *)theTimer
{
    if ([QCARHelper targetStatus] == kTargetStatusRequesting)
    {
        statusLabel.hidden = NO;
    }
    else
    {
        statusLabel.hidden = YES;
    }
}

- (CGRect) rectForStatusLabelWithString:(NSString *)aString
{
    UIFont *statusLabelFont = nil;
    float statusLabelBottomMargin = 0;
    
    if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        statusLabelFont = [UIFont fontWithName:@"Helvetica" size:18];
        statusLabelBottomMargin = 75;
    }
    else
    {
        statusLabelFont = [UIFont fontWithName:@"Helvetica" size:14];
        statusLabelBottomMargin = 40;
    }
    
    float statusLabelHeight = [aString sizeWithFont:statusLabelFont].height * 2.25;
    float statusLabelWidth = [aString sizeWithFont:statusLabelFont].width * 1.75;
    
    CGRect aRect = CGRectMake(self.view.frame.size.width/2 - statusLabelWidth/2,
                              self.view.frame.size.height - statusLabelHeight - statusLabelBottomMargin,
                              statusLabelWidth,
                              statusLabelHeight);
    
    return aRect;
}

- (void) addStatusLabel
{
    //  Adds "Requesting" black label at the bottom of the screen
    
    NSString *statusLabelText = @"Requesting";
    
    CGRect aRect = [self rectForStatusLabelWithString:statusLabelText];
    statusLabel = [[[UILabel alloc] initWithFrame:aRect] autorelease];
    
    statusLabel.text = statusLabelText;
    statusLabel.textAlignment =  UITextAlignmentCenter;
    statusLabel.textColor = [UIColor whiteColor];
    statusLabel.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    statusLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin;
    //  Hide it by default
    statusLabel.hidden = YES;
    
    [self.view addSubview:statusLabel];
    statusTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(refreshStatusLabel:)
                                                      userInfo:nil
                                                       repeats:YES] retain];
}

- (void)addCloseButton
{
    //  Adds close button on the upper right corner
    
    UIImage *closeButtonImage = [UIImage imageNamed:@"button_close_normal.png"];
    UIImage *closeButtonTappedImage = [UIImage imageNamed:@"button_close_pressed.png"];
    
    CGRect aRect = CGRectMake(self.view.frame.size.width - closeButtonImage.size.width,
                              0,
                              closeButtonImage.size.width,
                              closeButtonImage.size.height);
    
    closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = aRect;
    
    [closeButton setImage:closeButtonImage forState:UIControlStateNormal];
    [closeButton setImage:closeButtonTappedImage forState:UIControlStateHighlighted];
    
    closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
    [closeButton addTarget:self action:@selector(closeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:closeButton];
}

#pragma mark - Public

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self addStatusLabel];
    [self addCloseButton];
    [self addLoadingView];
    
    //  Loading view should be visible only on the requests
    loadingView.hidden = YES;
    
    //  Just show closeButton when an AR book is on display
    closeButton.hidden = YES;
    
    [self.view setUserInteractionEnabled:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetFound:) name:@"kTargetFound" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetLost:) name:@"kTargetLost" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetReacquired:) name:@"kTargetReacquired" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookWebDetailDismissed:) name:@"kBookWebDetailDismissed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startLoading:) name:@"kStartLoading" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopLoading:) name:@"kStopLoading" object:nil];
}

-(void) dealloc
{
    self.targetOverlayView = nil;
    self.arViewController = nil;
    
    [statusTimer invalidate];
    [statusTimer release];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    //  Since CRParentViewController does not inherit from BaseViewController,
    //  we have to override this behavior
    
    BOOL retVal = [[CRQCARutils getInstance] shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
    return retVal;
}


- (void) populateActionSheet
{
    flashIx = MENU_OPTION_WANTED;
    [super populateActionSheet];
}


#pragma mark - Notifications
- (void)startLoading:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        loadingView.hidden = NO;
        closeButton.hidden = NO;
    });
}

- (void)stopLoading:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        loadingView.hidden = YES;
        [self removeBookFromScreen];
    });
}

- (void)targetFound:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.targetOverlayView = [[[NSBundle mainBundle] loadNibNamed:@"targetOverlayView" owner:nil options:nil] objectAtIndex:0];
        
        Book *aBook = [notification object];
        [self.targetOverlayView setBook:aBook];
        [CRQCARutils getInstance].lastScannedBook = aBook;
        
        [self.arViewController setOverlayLayer:self.targetOverlayView.layer];
        [self.view addSubview:self.targetOverlayView];
        [self.targetOverlayView setHidden:YES];
        
        [self centerViewInFrame];
        
        loadingView.hidden = YES;
        
        //  Show close button
        closeButton.hidden = NO;
    });
}

- (void)targetReacquired:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.targetOverlayView setHidden:YES];
    });
}

- (void)targetLost:(NSNotification *)notification
{    
    dispatch_async(dispatch_get_main_queue(), ^{    
        [self.targetOverlayView setHidden:NO];
    });
}

- (void)bookWebDetailDismissed:(NSNotification *)notification
{
    /*  After the book detail webView is dismissed, the ARTracker will lost focus of it's 
     *  target and will popup the 2D book overlay. We have to close it as soon it appears
     */
    [self removeBookFromScreen];
}

#pragma mark - Actions

- (void) closeButtonTapped:(id)sender
{
    if (YES == [[BooksManager sharedInstance] isNetworkOperationInProgress])
    {
        // Cancel the network operation
        [[BooksManager sharedInstance] cancelNetworkOperations:YES];
    }
    else
    {
        [self removeBookFromScreen];
    }
}
@end
