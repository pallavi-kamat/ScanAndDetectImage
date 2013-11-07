/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import <UIKit/UIKit.h>
#import "BaseViewController.h"

@interface AboutViewController : BaseViewController <UIWebViewDelegate>
{
    IBOutlet UIWebView *webView;
}

- (IBAction)startButtonTapped:(id)sender;

@end
