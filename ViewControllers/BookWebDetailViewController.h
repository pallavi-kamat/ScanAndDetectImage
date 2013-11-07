/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import <UIKit/UIKit.h>
#import "Book.h"
#import "BaseViewController.h"

@interface BookWebDetailViewController : BaseViewController
{
    IBOutlet UIWebView *webView;
    IBOutlet UINavigationBar *navigationBar;
    
    Book *book;
}

-(id)initWithBook:(Book *)aBook;

@property (retain) Book *book;

- (IBAction)doneButtonTapped:(id)sender;
@end
