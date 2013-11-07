/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "ARViewController.h"
#import "CRQCARutils.h"

@class EAGLView, VSQCARutils;

@interface CRViewController : ARViewController
{   

}

- (void)setOverlayLayer:(CALayer *)overlayLayer;
- (void)enterScanningMode;
- (BOOL)isPointInsideAROverlay:(CGPoint)aPoint;
@end
