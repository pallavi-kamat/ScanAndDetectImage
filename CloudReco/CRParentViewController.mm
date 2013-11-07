/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "CRParentViewController.h"
#import "CRViewController.h"
#import "CROverlayViewController.h"
#import "EAGLView.h"
#import "QCARHelper.h"
#import "CRQCARutils.h"
#import "BookWebDetailViewController.h"
#import "TargetOverlayView.h"
#import "AboutViewController.h"

@implementation CRParentViewController // subclass of ARParentViewController

#pragma mark - Notifications

-(void)targetOverlayViewTapped:(NSNotification *)aNotification
{
    Book *aBook = [CRQCARutils getInstance].lastScannedBook;
    if (aBook)
    {
        BookWebDetailViewController *bookWebDetailViewController = [[[BookWebDetailViewController alloc] initWithBook:aBook] autorelease];
        [self presentModalViewController:bookWebDetailViewController animated:YES];
    }
}

#pragma mark - Public

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    [self createParentViewAndSplashContinuation];
    
    // Add the EAGLView
    arViewController = [[CRViewController alloc] init];
    
    // need to set size here to setup camera image size for AR
    arViewController.arViewSize = arViewRect.size;
    [parentView addSubview:arViewController.view];
    
    // Hide the AR view so the parent view can be seen during start-up (the
    // parent view contains the splash continuation image on iPad and is empty
    // on iPhone and iPod)
    [arViewController.view setHidden:YES];
    
    // Create an auto-rotating overlay view and its view controller (used for
    // displaying UI objects, such as the camera control menu)
    CROverlayViewController *vsoVC = [[CROverlayViewController alloc] init];
    vsoVC.arViewController = (CRViewController *)arViewController;
    overlayViewController = vsoVC;
    [parentView addSubview: overlayViewController.view];
    
    self.view = parentView;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetOverlayViewTapped:) name:@"kTargetOverlayViewTapped" object:nil];
}

- (void) dealloc
{
    [super dealloc];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //  Its superclass handles the overlay (2 taps) call
    [super touchesEnded:touches withEvent:event];
    
    UITouch* touch = [touches anyObject];
    
    if ([touch tapCount] == 1)
    {
        //  Get last scanned book
        Book *aBook = [CRQCARutils getInstance].lastScannedBook;
        
        if (aBook)
        {
            CROverlayViewController *ovc = (CROverlayViewController *)overlayViewController;
            
            if (ovc.targetOverlayView.isHidden)
            {
                //  It's displaying the attached view
                CGPoint touchLocation = [touch locationInView:self.view];
                if ([(CRViewController *)arViewController isPointInsideAROverlay:touchLocation])
                {
                    //  Show Book WebView Detail
                    BookWebDetailViewController *bookWebDetailViewController = [[[BookWebDetailViewController alloc] initWithBook:aBook] autorelease];
                    [self presentModalViewController:bookWebDetailViewController animated:YES];
                }
                
                //  We don't have to worry about the dettached view,
                //  TargetOverlayView has it's own touchesEnded call
            }
        }
    }    
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    //  Since CRParentViewController does not inherit from BaseViewController,
    //  we have to override this behavior
    
    BOOL retVal = [[CRQCARutils getInstance] shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
    return retVal;
}

#pragma mark -
#pragma mark Splash screen control
- (void)endSplash:(NSTimer*)theTimer
{
    // Poll to see if the camera video stream has started and if so remove the
    // splash screen
    [super endSplash:theTimer];
    
    if ([QCARutils getInstance].videoStreamStarted == YES)
    {
        // Create and show the about view
        AboutViewController *aboutViewController = [[[AboutViewController alloc] init] autorelease];
        aboutViewController.modalPresentationStyle = UIModalPresentationFormSheet;
        
        // Animate the modal only if it's an iPad
        BOOL shouldAnimateTransition = NO;
        if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        {
            shouldAnimateTransition = YES;
        }
        
        dispatch_async( dispatch_get_main_queue(), ^{
            [self presentModalViewController:aboutViewController animated:shouldAnimateTransition];
        });
    }
}

@end
