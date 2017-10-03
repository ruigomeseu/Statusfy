//
//  SFYAppDelegate.m
//  Statusfy
//
//  Created by Paul Young on 4/16/14.
//  Copyright (c) 2014 Paul Young. All rights reserved.
//

#import "SFYAppDelegate.h"


static NSString * const SFYPlayerStatePreferenceKey = @"ShowPlayerState";
static NSString * const SFYPlayerDockIconPreferenceKey = @"YES";

@interface SFYAppDelegate ()

@property (nonatomic, strong) NSMenuItem *playerStateMenuItem;
@property (nonatomic, strong) NSMenuItem *dockIconMenuItem;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property int firstPaused;
@property int lastNotified;
@property int timesNotified;

@end

@implementation SFYAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification * __unused)aNotification
{
    //Initialize the variable the getDockIconVisibility method checks
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SFYPlayerDockIconPreferenceKey];
    
    // Default to hidden dock icon
    [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
    
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.highlightMode = NO;
    
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    
    self.playerStateMenuItem = [[NSMenuItem alloc] initWithTitle:[self determinePlayerStateMenuItemTitle] action:@selector(togglePlayerStateVisibility) keyEquivalent:@""];
    
    self.dockIconMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Hide Dock Icon", nil) action:@selector(toggleDockIconVisibility) keyEquivalent:@""];
    
    [menu addItem:self.playerStateMenuItem];
    [menu addItem:self.dockIconMenuItem];
    [menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(quit) keyEquivalent:@"q"];

    [self.statusItem setMenu:menu];
    
    self.firstPaused = 0;
    self.lastNotified = 0;
    self.timesNotified = 0;
    
    [self setStatusItemTitle];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setStatusItemTitle) userInfo:nil repeats:YES];
}

#pragma mark - Setting title text

- (void)setStatusItemTitle
{
    NSString *trackName = [[self executeAppleScript:@"get name of current track"] stringValue];
    NSString *artistName = [[self executeAppleScript:@"get artist of current track"] stringValue];
    
    if (trackName && artistName) {
        NSString *titleText = [NSString stringWithFormat:@"%@ %@", trackName, artistName];
        
        NSRange range = [titleText rangeOfString:artistName];
        NSColor *color = [NSColor colorWithWhite:0.5 alpha:1.0];
        NSDictionary *defaultAttributes = [NSDictionary
                                           dictionaryWithObjectsAndKeys:
                                           [NSColor colorWithWhite:0.0 alpha:1.0],NSForegroundColorAttributeName,
                                           [NSFont menuBarFontOfSize:11], NSFontAttributeName,
                                           nil];
        
        NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] initWithString:titleText attributes:defaultAttributes];
        
        [attString addAttribute:NSForegroundColorAttributeName value:color range:range];
        
        if ([self getPlayerStateVisibility]) {
            NSString *formattedString = [NSString stringWithFormat:@" %@", [self determinePlayerStateText]];
            NSAttributedString *playerState = [[NSAttributedString alloc] initWithString:formattedString attributes:defaultAttributes];
            [attString appendAttributedString:playerState];
        }
        
        
        self.statusItem.image = nil;
        [self.statusItem setAttributedTitle:attString];
        self.statusItem.button.frame = CGRectMake(0.0, -1.5, self.statusItem.button.frame.size.width, self.statusItem.button.frame.size.height);
    }
    else {
        NSImage *image = [NSImage imageNamed:@"status_icon"];
        [image setTemplate:true];
        self.statusItem.image = image;
        self.statusItem.title = nil;
    }
}

#pragma mark - Executing AppleScript

- (NSAppleEventDescriptor *)executeAppleScript:(NSString *)command
{
    command = [NSString stringWithFormat:@"if application \"Spotify\" is running then tell application \"Spotify\" to %@", command];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:command];
    NSAppleEventDescriptor *eventDescriptor = [appleScript executeAndReturnError:NULL];
    return eventDescriptor;
}

#pragma mark - Player state

- (BOOL)getPlayerStateVisibility
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:SFYPlayerStatePreferenceKey];
}

- (void)setPlayerStateVisibility:(BOOL)visible
{
    [[NSUserDefaults standardUserDefaults] setBool:visible forKey:SFYPlayerStatePreferenceKey];
}

- (void)togglePlayerStateVisibility
{
    [self setPlayerStateVisibility:![self getPlayerStateVisibility]];
    self.playerStateMenuItem.title = [self determinePlayerStateMenuItemTitle];
}

- (NSString *)determinePlayerStateMenuItemTitle
{
    return [self getPlayerStateVisibility] ? NSLocalizedString(@"Hide Player State", nil) : NSLocalizedString(@"Show Player State", nil);
}

- (NSString *)determinePlayerStateText
{
    NSString *playerStateText = nil;
    NSString *playerStateConstant = [[self executeAppleScript:@"get player state"] stringValue];
    
    if ([playerStateConstant isEqualToString:@"kPSP"]) {
        self.firstPaused = 0;
        self.lastNotified = 0;
        self.timesNotified = 0;
        playerStateText = NSLocalizedString(@"▶️", nil);
    }
    else if ([playerStateConstant isEqualToString:@"kPSp"]) {
        
        int timeInSeconds = floor(CFAbsoluteTimeGetCurrent());
        
        if(self.firstPaused == 0) {
            self.firstPaused = timeInSeconds;
        } else {
            int secondsPassed = timeInSeconds - self.firstPaused;
            
            if(secondsPassed > 60) {
                int secondsPassedNotification = timeInSeconds - self.lastNotified;
                
                if(self.lastNotified == 0)
                {
                    self.lastNotified = timeInSeconds;
                    self.timesNotified = self.timesNotified + 1;
                    [self showNotification];
                } else {
                    if(secondsPassedNotification > 300 * self.timesNotified) {
                        self.lastNotified = timeInSeconds;
                        self.timesNotified = self.timesNotified + 1;
                        [self showNotification];
                    }
                }
            }
        }
        
        playerStateText = NSLocalizedString(@"⏸", nil);
    }
    else {
        playerStateText = NSLocalizedString(@"⏹", nil);
    }
    
    return playerStateText;
}

- (void)showNotification
{
    //Initalize new notification
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    //Set the title of the notification
    [notification setTitle:@"Spotify is paused"];
    //Set the text of the notification
    [notification setInformativeText:@"You haven't been listening to music for a while.."];
    //Set the sound, this can be either nil for no sound, NSUserNotificationDefaultSoundName for the default sound (tri-tone) and a string of a .caf file that is in the bundle (filname and extension)
    [notification setSoundName:nil];
    
    //Get the default notification center
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    //Scheldule our NSUserNotification
    [center scheduleNotification:notification];
}


#pragma mark - Toggle Dock Icon

- (BOOL)getDockIconVisibility
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:SFYPlayerDockIconPreferenceKey];
}

- (void)setDockIconVisibility:(BOOL)visible
{
   [[NSUserDefaults standardUserDefaults] setBool:visible forKey:SFYPlayerDockIconPreferenceKey];
}

- (void)toggleDockIconVisibility
{
    [self setDockIconVisibility:![self getDockIconVisibility]];
    self.dockIconMenuItem.title = [self determineDockIconMenuItemTitle];
    
    if(![self getDockIconVisibility])
    {
        //Apple recommended method to show and hide dock icon
        //hide icon
        [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
    }
    else
    {
        //show icon
        [NSApp setActivationPolicy: NSApplicationActivationPolicyRegular];
    }
}

- (NSString *)determineDockIconMenuItemTitle
{
    return [self getDockIconVisibility] ? NSLocalizedString(@"Hide Dock Icon", nil) : NSLocalizedString(@"Show Dock Icon", nil);
}

#pragma mark - Quit

- (void)quit
{
    [[NSApplication sharedApplication] terminate:self];
}

@end
