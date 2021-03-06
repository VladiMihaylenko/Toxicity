//
//  ChatWindowViewController.m
//  Toxicity
//
//  Created by James Linnell on 8/8/13.
//  Copyright (c) 2013 JamesTech. All rights reserved.
//

#import "TXCGroupChatWindowViewController.h"
#import "JSMessage.h"
#import "JSBubbleImageViewFactory.h"
#import "TXCSingleton.h"
#import "TXCAppDelegate.h"

static NSString *const kSenderMe = @"Me";
extern NSString *const TXCToxAppDelegateNotificationNewMessage;

@interface TXCGroupChatWindowViewController ()

@property (nonatomic, strong) NSMutableArray *mainGroupList;
@property (nonatomic, strong) NSMutableArray *mainGroupMessages;
@property (nonatomic, strong) TXCGroupObject *groupInfo;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSIndexPath *friendIndex;
@property (nonatomic, strong) UIImageView *statusNavBarImageView;

@end

@implementation TXCGroupChatWindowViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithFriendIndex:(NSIndexPath *)theIndex {
    
    self = [super init];
    if (self) {
        self.friendIndex = theIndex;
        
        self.mainGroupList = [[TXCSingleton sharedSingleton] groupList];
        self.mainGroupMessages = [[TXCSingleton sharedSingleton] groupMessages];
        
        self.messages = [[self.mainGroupMessages objectAtIndex:theIndex.row] mutableCopy];
        
        self.groupInfo = [self.mainGroupList objectAtIndex:theIndex.row];
        
        [[TXCSingleton sharedSingleton] setCurrentlyOpenedFriendNumber:self.friendIndex];
    }
    return self;
}

- (void)viewDidLoad
{
    self.delegate = self;
    self.dataSource = self;
    [super viewDidLoad];
    
    [[JSBubbleView appearance] setFont:[UIFont systemFontOfSize:16.0f]];
    self.messageInputView.textView.placeHolder = @"";
    self.sender = kSenderMe;
    [self setBackgroundColor:[UIColor colorWithRed:0.4f green:0.4f blue:0.4f alpha:1.0f]];
    
    if (!self.groupInfo.groupName.length) {
        self.title = self.groupInfo.groupPulicKey;
    } else {
        self.title = self.groupInfo.groupName;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self scrollToBottomAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
//    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newMessage:)
                                                 name:TXCToxAppDelegateNotificationNewMessage
                                               object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [TXCSingleton sharedSingleton].groupMessages[self.friendIndex.row] = self.messages.mutableCopy;
    [[TXCSingleton sharedSingleton] setCurrentlyOpenedFriendNumber:[NSIndexPath indexPathForItem:-1 inSection:-1]];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications Center stuff

- (void)updateUserInfo {
    if (!self.groupInfo.groupName.length)
        self.title = self.groupInfo.groupPulicKey;
    else
        self.title = self.groupInfo.groupName;
    
    //todo: status (where to display?) and status type
}

- (void)newMessage:(NSNotification *)notification {
    TXCMessageObject *receivedMessage = [notification object];
    
    if ([receivedMessage.senderKey isEqualToString:self.groupInfo.groupPulicKey]) {
        [self.tableView beginUpdates];
        
        [self.messages addObject:receivedMessage];
        
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForItem:(self.messages.count - 1) inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
        [self.tableView endUpdates];
        
        [self scrollToBottomAnimated:YES];
        [JSMessageSoundEffect playMessageReceivedSound];
    }
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messages.count;
}

#pragma mark - Messages view delegate
- (void)didSendText:(NSString *)text fromSender:(NSString *)sender onDate:(NSDate *)date
{
    TXCMessageObject *tempMessage = [[TXCMessageObject alloc] init];
    tempMessage.recipientKey = self.groupInfo.groupPulicKey;
    
    if ([text length] >= 5) {
        //only check for the "/me " if the message is 5 or more characters in length.
        //5 because we can't send a blank action
        //text:"/me " the action would be ""
        //text:"/me h" the action would be "h"
        if ([[text substringToIndex:4] isEqualToString:@"/me "]) {
            tempMessage.message = [[NSString alloc] initWithFormat:@"* %@", [text substringFromIndex:4]];
            tempMessage.actionMessage = YES;
        } else {
            tempMessage.message = [text copy];
            tempMessage.actionMessage = NO;
        }
    } else {
        tempMessage.message = [text copy];
    }
    tempMessage.origin = MessageLocation_Me;
    tempMessage.didFailToSend = NO;
    tempMessage.groupMessage = YES;
    
    TXCAppDelegate *ourDelegate = (TXCAppDelegate *)[[UIApplication sharedApplication] delegate];
    BOOL success = [ourDelegate sendMessage:tempMessage];
    if (!success) {
        tempMessage.didFailToSend = YES;
    }
    
    //add the message after we know if it failed or not
//    [messages addObject:tempMessage];
    
    [self finishSend];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TXCMessageObject *tempMessage = [self.messages objectAtIndex:indexPath.row];
    return tempMessage.origin == MessageLocation_Me ? JSBubbleMessageTypeOutgoing : JSBubbleMessageTypeIncoming;
}

- (UIImageView *)bubbleImageViewWithType:(JSBubbleMessageType)type forRowAtIndexPath:(NSIndexPath *)indexPath
{
    TXCMessageObject *tempMessage = [self.messages objectAtIndex:indexPath.row];
    if (tempMessage.origin == MessageLocation_Me) {
        return [JSBubbleImageViewFactory bubbleImageViewForType:type color:[UIColor js_bubbleBlueColor]];
    } else {
        return [JSBubbleImageViewFactory bubbleImageViewForType:type color:[UIColor js_bubbleLightGrayColor]];
    }
}

- (JSMessageInputViewStyle)inputViewStyle {
    return JSMessageInputViewStyleFlat;
}

- (BOOL)shouldPreventScrollToBottomWhileUserScrolling
{
    return YES;
}

- (BOOL)shouldDisplayTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)allowsPanToDismissKeyboard {
    return YES;
}

- (BOOL)hasTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (JSMessage *)messageForRowAtIndexPath:(NSIndexPath *)indexPath {
    TXCMessageObject *tempMessage = [self.messages objectAtIndex:indexPath.row];
    return [[JSMessage alloc] initWithText:tempMessage.message
                                    sender:tempMessage.origin == MessageLocation_Me ? kSenderMe : tempMessage.senderName
                                      date:nil];
}

- (UIImageView *)avatarImageViewForRowAtIndexPath:(NSIndexPath *)indexPath sender:(NSString *)sender
{
    return nil;
}

- (void)configureCell:(JSBubbleMessageCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    TXCMessageObject *tempMessage = [self.messages objectAtIndex:indexPath.row];
    if (cell.subtitleLabel && tempMessage.origin == MessageLocation_Them) {
        cell.subtitleLabel.text = [tempMessage senderName];
    }
}


@end
