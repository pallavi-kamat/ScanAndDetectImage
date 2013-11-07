/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "CRViewController.h"
#import "EAGLView.h"

extern bool isActivityInPortraitMode;

@implementation CRViewController // subclass of ARViewController

#pragma mark - Public

- (void) handleARViewRotation:(UIInterfaceOrientation)interfaceOrientation
{
    CGPoint centre, pos;
    NSInteger rot;
    
    // Set the EAGLView's position (its centre) to be the centre of the window, based on orientation
    centre.x = arViewSize.width / 2;
    centre.y = arViewSize.height / 2;
    
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
    {
        NSLog(@"ARVC: Rotating to Portrait");
        pos = centre;
        rot = 90;
        qUtils.orientationChanged=true;
        isActivityInPortraitMode= true;
        qUtils.orientation = UIInterfaceOrientationPortrait;
               
        CGRect viewBounds;
        viewBounds.origin.x = 0;
        viewBounds.origin.y = 0;
        viewBounds.size.width = arViewSize.width;
        viewBounds.size.height = arViewSize.height;
        
        [arView setFrame:viewBounds]; 
        
    }
    else if (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        NSLog(@"ARVC: Rotating to Upside Down");        
        pos = centre;
        rot = 270;
        qUtils.orientationChanged=true;
        isActivityInPortraitMode= true;
        qUtils.orientation = UIInterfaceOrientationPortraitUpsideDown;
                
        CGRect viewBounds;
        viewBounds.origin.x = 0;
        viewBounds.origin.y = 0;
        viewBounds.size.width = arViewSize.width;
        viewBounds.size.height = arViewSize.height;
        
        [arView setFrame:viewBounds];
    }
    else if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
    {
        NSLog(@"ARVC: Rotating to Landscape Left");        
        pos.x = centre.y;
        pos.y = centre.x;
        rot = 180;
        qUtils.orientationChanged=true;
        isActivityInPortraitMode= false;
        qUtils.orientation = UIInterfaceOrientationLandscapeLeft;
        
        CGRect viewBounds;
        viewBounds.origin.x = 0;
        viewBounds.origin.y = 0;
        viewBounds.size.width = arViewSize.height;
        viewBounds.size.height = arViewSize.width;
        
        [arView setFrame:viewBounds];
    }
    else if (interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        NSLog(@"ARVC: Rotating to Landscape Right");
        pos.x = centre.y;
        pos.y = centre.x;
        rot = 0;
        qUtils.orientationChanged=true;
        isActivityInPortraitMode= false;
        qUtils.orientation = UIInterfaceOrientationLandscapeRight;
              
        CGRect viewBounds;
        viewBounds.origin.x = 0;
        viewBounds.origin.y = 0;
        viewBounds.size.width = arViewSize.height;
        viewBounds.size.height = arViewSize.width;
        
        [arView setFrame:viewBounds];
    }
    
}

- (void)setOverlayLayer:(CALayer *)overlayLayer
{
    [self.arView setOverlayLayer:overlayLayer];
}

- (void)enterScanningMode
{
    [self.arView enterScanningMode];
}

- (BOOL)isPointInsideAROverlay:(CGPoint)aPoint
{
    BOOL retVal = [self.arView isPointInsideAROverlay:aPoint];
    return retVal;
}

@end
