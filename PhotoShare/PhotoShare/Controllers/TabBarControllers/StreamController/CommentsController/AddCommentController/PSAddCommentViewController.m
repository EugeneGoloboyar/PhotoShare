//
//  PSAddCommentViewController.m
//  PhotoShare
//
//  Created by Евгений on 09.07.14.
//  Copyright (c) 2014 Eugene. All rights reserved.
//

#import "PSAddCommentViewController.h"
#import "PSNetworkManager.h"
#import "Post.h"
#import "Comment.h"
#import "PSCommentsParser.h"
#import "PSUserStore.h"
#import "User.h"
#import "User+PSMapWithModel.h"
#import "PScommentModel.h"
#import "Comment+mapWthModel.h"

@interface PSAddCommentViewController() <UITextViewDelegate>
- (IBAction)actionSendComment:(id)sender;
@property (nonatomic,weak) IBOutlet UITextView *commentTextView;
@property (nonatomic,assign)int userID;
@property (nonatomic,assign)BOOL waitingForResponse;

@property (nonatomic, strong)
NSString *textForComment;
@end

@implementation PSAddCommentViewController



- (void)viewDidLoad
{
    [super viewDidLoad];
    PSUserStore *userStore= [PSUserStore userStoreManager];
    User *currentUser=userStore.activeUser;
    _userID=[currentUser.user_id intValue];
    NSLog(@"user_id:%d",_userID);
    _waitingForResponse=NO;
    _textForComment=@"Text for comment";
}

- (IBAction)dismissKeyboard:(id)sender {
    [[self view] endEditing:YES];
}


- (IBAction)actionSendComment:(id)sender {
    if (_waitingForResponse) return;
    _waitingForResponse=YES;
    
    [[PSNetworkManager sharedManager] commentPostID:[_postToComment.postID intValue]
        fronUserID:_userID
        withText:_textForComment
        success:^(id responseObject) {
            UIAlertView *alert=[[UIAlertView alloc]
                                initWithTitle:NSLocalizedString(@ "alertViewOkKey", "")
                                message:NSLocalizedString(@"alertViewSuccessKey", "")
                                delegate:nil
                                cancelButtonTitle:NSLocalizedString(@"alertViewOkKey", "")
                                otherButtonTitles:nil, nil];
            [alert show];
            PSCommentModel *commentModel=[[PSCommentModel alloc]init];
            PSCommentsParser *commentParser=[PSCommentsParser new];
            commentModel.commentText=[commentParser getCommentText:responseObject];
            commentModel.commentatorName=[commentParser getAuthorName:responseObject];
            commentModel.commentID=[commentParser getCommentID:responseObject];
            commentModel.commentDateString=[commentParser getCommentTime:responseObject];
            Comment *commentToAdd=[Comment MR_createEntity];
            commentToAdd=[commentToAdd commentWithMapModel:commentModel];
            [_postToComment addCommentsObject:commentToAdd];
            [_postToComment.managedObjectContext MR_saveToPersistentStoreAndWait];
            _waitingForResponse=NO;
            
        } error:^(NSError *error) {
        
    }];
}


#pragma mark - UITextViewDelegate
- (void)textViewDidEndEditing:(UITextView *)textView {
    _textForComment=textView.text;
    
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return textView.text.length + (text.length - range.length) <= 256;
}

@end

