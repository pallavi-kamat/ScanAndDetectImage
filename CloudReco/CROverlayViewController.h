/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/


#import "OverlayViewController.h"

@class QCARutils;
@class TargetOverlayView;
@class CRViewController;

// OverlayViewController class overrides one UIViewController method
@interface CROverlayViewController : OverlayViewController
{
    UILabel *statusLabel;
    UIButton *closeButton;
    NSTimer *statusTimer;
    
    UIView *loadingView;
}

@property (nonatomic, retain) IBOutlet TargetOverlayView *targetOverlayView;
@property (nonatomic, retain) CRViewController *arViewController;

@end
