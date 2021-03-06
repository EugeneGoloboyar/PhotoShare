//
//  PSStreamViewController.m
//  PhotoShare
//
//  Created by Евгений on 12.06.14.
//  Copyright (c) 2014 Eugene. All rights reserved.
//

#import "PSStreamViewController.h"
#import "UIImageView+AFNetworking.h"
#import "Post.h"
#import "Comment.h"
#import "PSPhotoFromStreamTableViewCell.h"
#import "UIScrollView+SVPullToRefresh.h"
#import "UIScrollView+SVInfiniteScrolling.h"
#import "UIViewController+UIViewController_PSSharingDataComposer.h"

typedef enum {
    kNew,
    kFavourite
} sortPostsByKey;

static NSString *keyForPostID                                 =@"post_id";
static NSString *keyForPhotoDate                              =@"photo_date";
static NSString *keyForLikes                                  =@"likes";
static NSString *keyForAuthorMail                             =@"authoremail";
static NSString *keyForPhotoName                              =@"photoName";
static NSString *keyForPhotoURL                               =@"photoURL";
static NSString *keyForLocationDictionary                     =@"location";
static NSString *keyPathForLatitude                           =@"location.latitude";
static NSString *keyPathForLongtitude                         =@"location.longitude";
static NSString *keyForCommentsArray                          =@"comments";
static NSString *keyForCommentIDInComments                    =@"comment_id";
static NSString *keyForCommentatorNameInComments              =@"commentatorName";
static NSString *keyForCommentTextInComments                  =@"text";
static NSString *keyForCommentDateInComments                  =@"comment_date";

static NSString *keyForSortSettings                           =@"sortKey";



@interface PSStreamViewController() <UITableViewDelegate ,UITableViewDataSource, NSFetchedResultsControllerDelegate, PhotoFromStreamTableViewCell,UIActionSheetDelegate>
//@property (weak, nonatomic) IBOutlet UIImageView *imageFromPost;

@property (nonatomic, strong) NSNumber * post_idParsed;
@property (nonatomic, strong) NSNumber * likesParsed;
@property (nonatomic, copy) NSString * authorMailParsed;
@property (nonatomic, copy) NSString * photoNameParsed;
@property (nonatomic, copy) NSString * photoURLParsed;
@property (nonatomic, copy) NSDate * photo_dateParsed;

@property (nonatomic, assign) NSInteger cellCount;

@property (nonatomic,strong) NSNumber * commentIDParsed;
@property (nonatomic,copy) NSString * commentatorNameParsed;
@property (nonatomic,copy) NSString * commentTextParsed;
@property (nonatomic,copy) NSDate * commentDateParsed;
@property (nonatomic,assign) NSUInteger offset;
@property (nonatomic, strong) NSData *imageDataToShare;
@property (nonatomic, copy)  NSString *photoName;

@property (nonatomic, strong) NSMutableArray *dataSource;

- (IBAction)switchSortKey:(id)sender;
@property (weak, nonatomic) IBOutlet UISegmentedControl *changeSortKeySegmentController;


@property (nonatomic,assign) double photoLatitudeParsed;
@property (nonatomic,assign) double photoLongtitudeParsed;

@property (nonatomic,assign) sortPostsByKey sortKey;

@property (weak, nonatomic) IBOutlet UITableView *streamTableView;
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (strong,nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic,strong) NSFetchedResultsController
    *likeFetchedResultsController;
@property (nonatomic,strong) NSFetchedResultsController
    *dateFetchedResultsController;

@end



@implementation PSStreamViewController


-(void)viewDidLoad {
   
    
    [super viewDidLoad];
    [self loadSettins];
    self.offset=5;
    _cellCount=0;
    self.streamTableView.contentSize=CGSizeMake(self.streamTableView.bounds.size.width,330.0f);
    
    self.streamTableView.clipsToBounds=NO;
    
    [self setAutomaticallyAdjustsScrollViewInsets:NO];
    
    NSData *dataFromJSON=[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"response1" ofType:@"json" inDirectory:nil]];
    NSLog(@"file context:%@",dataFromJSON);
    
    NSMutableArray *parsedData= [[NSJSONSerialization JSONObjectWithData:dataFromJSON
                                                    options:0 error:nil] mutableCopy];
    NSLog(@"parsedArray:%@",parsedData);

    NSDictionary* searchedPost=[NSDictionary new];
    
    
    //sort array by date
    NSSortDescriptor *descriptor=[[NSSortDescriptor alloc] initWithKey:@"photo_date" ascending:NO];
    NSArray *descriptors=[NSArray arrayWithObject: descriptor];
    NSArray *reverseOrder=[parsedData sortedArrayUsingDescriptors:descriptors];
    
    parsedData=[reverseOrder mutableCopy];
  
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
    //writing posts to CoreData
    for (NSDictionary *dict in parsedData)
    {
        
        //Reading data from JSON
        self.post_idParsed=[dict objectForKey:keyForPostID];
        NSLog(@"post_id:%@",self.post_idParsed);
        self.likesParsed=[dict objectForKey:keyForLikes];
        NSLog(@"likes:%@",self.likesParsed);
        self.authorMailParsed=[dict objectForKey:keyForAuthorMail];
        NSLog(@"authorMail:%@",self.authorMailParsed);
        self.photoNameParsed=[dict objectForKey:keyForPhotoName];
        NSLog(@"photoName:%@",self.photoNameParsed);
        self.photoURLParsed=[dict objectForKey:keyForPhotoURL];
        NSLog(@"photoURL:%@",self.photoURLParsed);
        
        
        //coordinates in degrees @"key1.@specialKey.
        self.photoLatitudeParsed=[[dict valueForKeyPath:keyPathForLatitude]doubleValue ];
        self.photoLongtitudeParsed=[[dict valueForKeyPath:keyPathForLongtitude] doubleValue];
        
        NSLog(@"latitudeParsed:%f",self.photoLatitudeParsed);
        NSLog(@"longtitudeParsed:%f",self.photoLongtitudeParsed);
        
        
        
        NSMutableArray *commentsArray=[dict objectForKey:keyForCommentsArray];
        NSLog(@"commentsArray:%@",commentsArray);


        NSLog(@"date:%@",[dict objectForKey:keyForPhotoDate]);
        
        self.photo_dateParsed=[dateFormatter dateFromString:[dict objectForKey:keyForPhotoDate]];
        
        NSLog(@"photo_date:%@",self.photo_dateParsed);
        

        
        //check if the parsed post exists in CoreData
        Post *existingPost=[[Post MR_findByAttribute:@"postID" withValue:self.post_idParsed]firstObject];
        
        if (!existingPost)
        {
            existingPost=[Post MR_createEntity];
            
            existingPost.postID=self.post_idParsed;
            existingPost.likes=self.likesParsed;
            existingPost.authorMail=self.authorMailParsed;
            existingPost.photoName=self.photoNameParsed;
            existingPost.photoURL=self.photoURLParsed;
            existingPost.photoDate=self.photo_dateParsed;
            existingPost.photoLocationLatitude=[NSNumber numberWithDouble:self.photoLatitudeParsed];
            existingPost.photoLocationLongtitude=[NSNumber numberWithDouble:self.photoLongtitudeParsed];
            

            
            //parse and check comments
            for (NSDictionary *dictOfComments in commentsArray)
            {
                
                self.commentIDParsed=[dictOfComments objectForKey:keyForCommentIDInComments];
                
                if ([[existingPost.comments filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"commentID == %@",self.commentIDParsed]] anyObject])
                {
                    NSLog(@"Post %@ has comment with id %@",existingPost.postID, self.commentIDParsed);
                    
                }
                
                else
                {
                    //parsed date,text,name of comment
                    self.commentatorNameParsed=[dictOfComments objectForKey:keyForCommentatorNameInComments];
                    self.commentTextParsed=[dictOfComments objectForKey:keyForCommentTextInComments];
                    self.commentDateParsed=[dateFormatter dateFromString:[dictOfComments objectForKey:keyForCommentDateInComments]];
                                            
                     NSLog(@"photo_date:%@",self.commentDateParsed);
                    
                    //creating an instance of Comment entity
                    
                    Comment *commentToAdd=[Comment MR_createEntity];
                    
                    commentToAdd.commentID=self.commentIDParsed;
                    commentToAdd.commentatorName=self.commentatorNameParsed;
                    commentToAdd.commentText=self.commentTextParsed;
                    commentToAdd.commentDate=self.commentDateParsed;
                    
                    [existingPost addCommentsObject:commentToAdd];
                }
                    
                
            }
            
            
            NSLog(@"added post with id:%@ to database", existingPost.postID);
            NSLog(@"Post coords:%@, %@",existingPost.photoLocationLatitude,existingPost.photoLocationLongtitude );
            [existingPost.managedObjectContext MR_saveToPersistentStoreAndWait];
            
        }
        
    
        else if (existingPost) {
            NSLog(@"Post with id:%@ already exists in database",existingPost.postID);
        }
    
        
    }
    
    
    
    //taking the last Post from sortded by date array
    searchedPost=[parsedData firstObject];
    
    
    NSLog(@"firstPost:%@",searchedPost);
    NSURL *urlForImage = [NSURL URLWithString:[searchedPost objectForKey:keyForPhotoURL]];
    [self.image setImageWithURL:urlForImage];
    self.streamTableView.dataSource=self;
    self.streamTableView.delegate=self;

//       __weak typeof(self) weakSelf = self;
//    [self.streamTableView addInfiniteScrollingWithActionHandler:^{
//        [weakSelf insertRowAtBottom];
//    }];
//  [self setAutomaticallyAdjustsScrollViewInsets:NO];

}


-(NSMutableArray *)dataSource {
    if (!_dataSource) {
        _dataSource=[NSMutableArray array];
    }
    return _dataSource;
}




#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = [Post MR_countOfEntities];
 //менять в
    if (_offset>count) {
        return count;
    }
    return _offset;
}


//PhotoShare[5505:60b] *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Invalid update: invalid number of rows in section 0.  The number of rows contained in an existing section after the update (10) must be equal to the number of rows contained in that section before the update (5), plus or minus the number of rows inserted or deleted from that section (1 inserted, 0 deleted) and plus or minus the number of rows moved into or out of that section (0 moved in, 0 moved out).'



//- (void)insertRowAtBottom {
//   __weak typeof(self) weakSelf = self;
//
//    int64_t delayInSeconds = 2.0;
//   dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//       [weakSelf.streamTableView beginUpdates];
//        _offset+=5;
//        
//              
//    [weakSelf.streamTableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:weakSelf.dataSource.count-1 inSection:0]] withRowAnimation:UITableViewRowAnimationTop];
//        
//        [weakSelf.streamTableView endUpdates];
//        
//        [weakSelf.streamTableView.infiniteScrollingView stopAnimating];
//    });
//}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
   
    
   PSPhotoFromStreamTableViewCell *cell=[self.streamTableView dequeueReusableCellWithIdentifier:@"photoCell"];
    
    
    
    [self configureCell:cell atIndexPath:indexPath];

    cell.selected=NO;
    return cell;
    
}



//This function is where all the magic happens
-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    
    
    //1. Setup the CATransform3D structure
    CATransform3D rotation;
    rotation = CATransform3DMakeRotation( (90.0*M_PI)/180, 0.0, 0.7, 0.4);
    //rotation = CATransform3DMakeRotation( (90.0*M_PI)/180, 1.0, 1.0, 0.0);
    rotation.m34 = 1.0/ -600;
    
    
    //2. Define the initial state (Before the animation)
    cell.layer.shadowColor = [[UIColor blackColor]CGColor];
    cell.layer.shadowOffset = CGSizeMake(10, 10);
    cell.alpha = 0;
    
    cell.layer.transform = rotation;
    cell.layer.anchorPoint = CGPointMake(0, 0.5);
    
    //!!!FIX for issue #1 Cell position wrong------------
    if(cell.layer.position.x != 0){
        cell.layer.position = CGPointMake(0, cell.layer.position.y);
    }
    
    //4. Define the final state (After the animation) and commit the animation
    [UIView beginAnimations:@"rotation" context:NULL];
    [UIView setAnimationDuration:0.8];
    //[UIView setAnimationDuration:5.8];
    cell.layer.transform = CATransform3DIdentity;
    cell.alpha = 1;
    cell.layer.shadowOffset = CGSizeMake(0, 0);
    [UIView commitAnimations];
}


- (NSFetchedResultsController *)likeFetchedResultsController {
    if (_likeFetchedResultsController!=nil) {
        return _likeFetchedResultsController;
    }
    
    NSFetchRequest* fetchRequest=[[NSFetchRequest alloc]initWithEntityName:@"Post"];
    NSSortDescriptor *descriptor=[NSSortDescriptor sortDescriptorWithKey:@"likes" ascending:NO];
    
    [fetchRequest setSortDescriptors:@[descriptor]];
     
     fetchRequest.fetchOffset=_offset;
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
  _likeFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:[NSManagedObjectContext MR_defaultContext]
                                                             sectionNameKeyPath:nil
                                                             cacheName:nil];
    
    
    _likeFetchedResultsController.delegate = self;

    
	NSError *error = nil;
	if (![self.likeFetchedResultsController performFetch:&error])
    {
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _likeFetchedResultsController;

}

- (NSFetchedResultsController *)dateFetchedResultsController {
    
    if (_dateFetchedResultsController!=nil) {
        return _dateFetchedResultsController;
    }
    
    NSFetchRequest* fetchRequest=[[NSFetchRequest alloc]initWithEntityName:@"Post"];
    NSSortDescriptor *descriptor=[NSSortDescriptor sortDescriptorWithKey:@"photoDate" ascending:NO];
    [fetchRequest setSortDescriptors:@[descriptor]];
    fetchRequest.fetchOffset=_offset;
    _dateFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:[NSManagedObjectContext MR_defaultContext]
                                                             sectionNameKeyPath:nil
                                                             cacheName:nil];
    
    
    _dateFetchedResultsController.delegate = self;
    
	NSError *error = nil;
	if (![self.dateFetchedResultsController performFetch:&error])
    {
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _dateFetchedResultsController;

}



- (NSFetchedResultsController *)fetchedResultsController
{
    if (self.sortKey==kNew) {
        _fetchedResultsController=self.dateFetchedResultsController;
        _offset=5;
    }
   
    else if (self.sortKey==kFavourite) {
        _fetchedResultsController=self.likeFetchedResultsController;
        _offset=5;
    }
    
    return _fetchedResultsController;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.streamTableView beginUpdates];
}




- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.streamTableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.streamTableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}



- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.streamTableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
    
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath];
            break;
      
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
        break;    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.streamTableView endUpdates];
}

#pragma mark - UITableViewDelegate

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    PSPhotoFromStreamTableViewCell *aCell = (id)cell;
    
    Post  *postTest=[self.fetchedResultsController objectAtIndexPath:indexPath];
    //cell=(PSPhotoFromStreamTableViewCell*)cell;
    
    aCell.postForCell=postTest;
    aCell.photoNameLabel.text=postTest.photoName;
    aCell.timeintervalLabel.text=[self timeIntervalFromPhoto:postTest.photoDate];
    NSString *commentsNumberString =[NSString stringWithFormat:@"%lu", (unsigned long)[postTest.comments count]];
    aCell.commentsNumberLabel.text=commentsNumberString;
    [aCell.imageForPost setImageWithURL: [NSURL URLWithString:postTest.photoURL]];
    aCell.likesNumberLabel.text=[NSString stringWithFormat:@"%@",postTest.likes];
    aCell.delegate=self;
    
    
}

- (NSString *)timeIntervalFromPhoto:(NSDate *) date
{
    NSTimeInterval timeIntervalBetweenPhotos=[date timeIntervalSinceNow];
    
    if ((timeIntervalBetweenPhotos/-86400>1))
    
    {
        return [NSString stringWithFormat:@"%i days ago",abs(timeIntervalBetweenPhotos/(60*60*24))];
    }
    
    else if ((timeIntervalBetweenPhotos/-3600)>1)
    {
        return [NSString stringWithFormat:@"%i hours ago",abs(timeIntervalBetweenPhotos/3600)];
    }
    
    else if ((timeIntervalBetweenPhotos/-60)>1)
    {
        return [NSString stringWithFormat:@"%i minutes ago",abs(timeIntervalBetweenPhotos/60)];
    }
    
    else
        return [NSString stringWithFormat:@"%i seconds ago",abs(timeIntervalBetweenPhotos)];
}


- (IBAction)switchSortKey:(id)sender
{
    
    UISegmentedControl *segmentedControl = (UISegmentedControl *) sender;
    NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
    
    if (selectedSegment == 0)
    {
        self.sortKey=kNew;
        [self saveSettings];
        [self.streamTableView setContentOffset:CGPointMake(0, 0)];
        [self.streamTableView reloadData];
        
    }
    else if (selectedSegment == 1)
    {
        self.sortKey=kFavourite;
        [self.streamTableView reloadData];
        [self.streamTableView setContentOffset:CGPointMake(0, 0)];
        [self saveSettings];
    }
    
}

#pragma mark - Save and Load

- (void)saveSettings {
    
    NSUserDefaults *userDefaults=[NSUserDefaults standardUserDefaults];
    
    if (self.sortKey==kNew) {
       [userDefaults setInteger:0 forKey:keyForSortSettings];
    }
    else if (self.sortKey==kFavourite) {
       [userDefaults setInteger:1 forKey:keyForSortSettings];
    }
    [userDefaults synchronize];
}

- (void)loadSettins {
    
    NSUserDefaults *userDefaults=[NSUserDefaults standardUserDefaults];
    int KeyFromDefaults;
    
    KeyFromDefaults=[userDefaults integerForKey:keyForSortSettings];
    
    if (KeyFromDefaults==0)
    {
        self.sortKey=kNew;
        self.changeSortKeySegmentController.selectedSegmentIndex=0;
    }
    
    else if (KeyFromDefaults==1)
    {
        self.sortKey=kFavourite;
        self.changeSortKeySegmentController.selectedSegmentIndex=1;
    }
    else
    {
        self.sortKey=kNew;
        self.changeSortKeySegmentController.selectedSegmentIndex=0;
    }
    
}

#pragma mark - PhotoFromStreamTableViewCell
- (void)photoStreamCellShareButtonPressed:(PSPhotoFromStreamTableViewCell  *)
tableCell
{
    NSData *data=[NSData new];
    data=[NSData dataWithContentsOfURL:[NSURL URLWithString:tableCell.postForCell.photoURL]];
    UIImage* image=[UIImage imageWithData:data];
    self.imageDataToShare=UIImageJPEGRepresentation(image, 1.0);
    self.photoName=tableCell.postForCell.photoName;
    
    UIActionSheet* actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:@"Share"
                                  delegate:self
                                  cancelButtonTitle:NSLocalizedString
                                  (@"actionSheetButtonCancelNameKey", "")
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:nil, nil];
    
    
    [actionSheet setTitle:NSLocalizedString(@"actionSheetTitleNameKey", "")];
    [actionSheet addButtonWithTitle:NSLocalizedString(@"actionSheetButtonEmailNameKey", "")];
    [actionSheet addButtonWithTitle:NSLocalizedString(@"actionSheetButtonTwitterNameKey", "")];
    [actionSheet addButtonWithTitle:NSLocalizedString(@"actionSheetButtonFacebookNameKey", "")];
    [actionSheet addButtonWithTitle:NSLocalizedString(@"actionSheetButtonSaveNameKey", "")];
    
    //without next line action sheet does not appear on iphone 3.5 inch
    [actionSheet showFromTabBar:(UIView*)self.view];



}



#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // NSLog(@"Была нажата кнопка с номером - %d",buttonIndex);
    //Cancel   0
    //Email    1
    //Twitter  2
    //FaceBook 3
    //Save     4
    
    
    switch (buttonIndex) {
        {case 1: //Email photo
            
            [self shareByEmail:_imageDataToShare photoName:_photoName
                       success:^
             {
                 
                 //NSLog(@"Photo was posted to facebook successfully");
                 UIAlertView *alert=[[UIAlertView alloc]
                                     initWithTitle:NSLocalizedString(@"alertViewSuccessKey", "")
                                     message:NSLocalizedString(@"alertViewOnMailSuccesstKey","")
                                     delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"alertViewOkKey", "")
                                     otherButtonTitles:nil, nil];
                 [alert show];
             }
             
             
                       failure:^(NSError *error)
             {
                 if (error.code==100)
                 {
                     UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"alertViewOnTwitterErrorNoPhotoKey", "") delegate:self cancelButtonTitle:NSLocalizedString(@"actionSheetButtonCancelNameKey", "")  otherButtonTitles:nil, nil];
                     [alert show];
                     
                 }
                 
                 else if (error.code==103)
                 {
                     UIAlertView *alert=[[UIAlertView alloc]
                                         initWithTitle:NSLocalizedString(@ "ErrorStringKey", "")
                                         message:NSLocalizedString(@"alertViewOnMailConfigerAccountKey","")
                                         delegate:nil
                                         cancelButtonTitle:NSLocalizedString(@"actionSheetButtonCancelNameKey", "")
                                         otherButtonTitles:nil, nil];
                     [alert show];
                 }
                 
             }];
            
            // [self shareByEmail:self.imageDataToShare];
            break;}
            
        {
        case 2:
            [self shareToTwitterWithData:_imageDataToShare
                               photoName:_photoName
                                 success:^
             {
                 NSLog(@"Photo was tweeted successfully");
                 UIAlertView *alert=[[UIAlertView alloc]
                                     initWithTitle:NSLocalizedString(@"alertViewSuccessKey", "")
                                     message:NSLocalizedString(@   "alertViewOnTwitterSuccesstKey","")
                                     delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"alertViewOkKey", "")
                                     otherButtonTitles:nil, nil];
                 [alert show];
                 
             }
             
                                 failure:^(NSError *error)
             {
                 
                 if (error.code==100)
                 {
                     UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"alertViewOnTwitterErrorNoPhotoKey", "") delegate:self cancelButtonTitle:NSLocalizedString(@"actionSheetButtonCancelNameKey", "")  otherButtonTitles:nil, nil];
                     [alert show];
                     
                 }
                 
                 else if (error.code==101)
                 {
                     UIAlertView *alert=[[UIAlertView alloc]
                                         initWithTitle:NSLocalizedString(@"alertViewOnTwitterConfigerAccountKey", "")
                                         message:NSLocalizedString(@"alertViewOnMailConfigerAccountKey","")
                                         delegate:nil
                                         cancelButtonTitle:NSLocalizedString(@"actionSheetButtonCancelNameKey", "")
                                         otherButtonTitles:nil, nil];
                     [alert show];
                 }
             }
             ];
            
            
            break;}
            
        {case 3:
            
            [self shareToFacebookWithData:_imageDataToShare photoName:_photoName
                                  success:^
             {
                 NSLog(@"Photo was successfully posted to facebook");
                 UIAlertView *alert=[[UIAlertView alloc]
                                     initWithTitle:NSLocalizedString(@"alertViewSuccessKey", "")
                                     message:NSLocalizedString(@ "alertViewOnFacebookSuccesstKey","")
                                     delegate:nil
                                     cancelButtonTitle:NSLocalizedString(@"alertViewOkKey", "")
                                     otherButtonTitles:nil, nil];
                 [alert show];
             }
                                  failure:^(NSError *error) {
                                      
                                      if (error.code==100)
                                      {
                                          UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"alertViewOnTwitterErrorNoPhotoKey", "") delegate:self cancelButtonTitle:NSLocalizedString(@"actionSheetButtonCancelNameKey", "")  otherButtonTitles:nil, nil];
                                          [alert show];
                                          
                                      }
                                      
                                      else if (error.code==102)
                                      {
                                          UIAlertView *alert=[[UIAlertView alloc] initWithTitle:NSLocalizedString(@ "ErrorStringKey", "")
                                                                                        message:NSLocalizedString(@"alertViewOnFacebookConfigerAccountKey", "")
                                                                                       delegate:self cancelButtonTitle:NSLocalizedString(@"actionSheetButtonCancelNameKey", "") otherButtonTitles:nil, nil];
                                          [alert show];
                                          
                                      }
                                      
                                  }];
            
            
            
            break;
        }
            
        {case 4:
            [self SaveToAlbumWithData:_imageDataToShare
                              success:^{
                                  UIAlertView *alert=[[UIAlertView alloc]
                                                      initWithTitle:NSLocalizedString(@"alertViewSuccessKey", "")
                                                      message:NSLocalizedString(@ "alertViewOnSaveSuccessKey", "")
                                                      delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"alertViewOkKey", "")
                                                      otherButtonTitles:nil, nil];
                                  [alert show];
                              }
                              failure:^(NSError *error) {
                                  
                                  UIAlertView *alert=[[UIAlertView alloc]
                                                      initWithTitle:NSLocalizedString(@"alertViewSuccessKey", "")
                                                      message:NSLocalizedString(@ "alertViewOnSaveSuccessKey", "")
                                                      delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"alertViewOkKey", "")
                                                      otherButtonTitles:nil, nil];
                                  [alert show];
                                  
                              }];
            
            break;
        }
        default:
            break;
    }
}




@end
