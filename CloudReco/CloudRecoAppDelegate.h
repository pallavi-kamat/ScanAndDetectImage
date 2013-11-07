/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/


#import <UIKit/UIKit.h>
@class CRParentViewController;


@interface CloudRecoAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow* window;
    CRParentViewController* arParentViewController;
    UIImageView *splashImageView;
}

@property (readonly, nonatomic) CRParentViewController* arParentViewController;
@end
