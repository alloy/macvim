#import "MMFileBrowser.h"
#import "MMFileBrowserFSItem.h"
#import "Miscellaneous.h"

#define ENTER_KEY_CODE 36
#define TAB_KEY_CODE 48
#define ESCAPE_KEY_CODE 53
#define LEFT_KEY_CODE 123
#define RIGHT_KEY_CODE 124
#define DOWN_KEY_CODE 125
#define UP_KEY_CODE 126

static NSString *LEFT_KEY_CHAR, *RIGHT_KEY_CHAR, *DOWN_KEY_CHAR, *UP_KEY_CHAR;

@implementation MMPathControl : NSPathControl

- (id)initWithFrame:(NSRect)frameRect parent:(MMFileBrowser*)parent {
    fileBrowser = parent;
    return [super initWithFrame:frameRect];
}

+ (Class)cellClass {
    return [MMPathCell class];
}
- (void) drawRect:(NSRect)dirtyRect {
    [self updateColors];
    NSRectFill (dirtyRect);
    [super drawRect:dirtyRect];
}

- (void)updateColors {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:MMSidebarUseVimThemeKey]){
        //background for path selector root element (not drawn by cells)
        [fileBrowser.sidebarBackgroundColor set];
        
        NSArray<NSPathComponentCell *> *cells = [self pathComponentCells];
        for (NSPathComponentCell* cell in cells) {
            [cell setTextColor:fileBrowser.sidebarForegroundColor];
        }
    } else {
        //set system standard colors
        NSArray<NSPathComponentCell *> *cells = [self pathComponentCells];
        for (NSPathComponentCell* cell in cells) {
            [cell setTextColor:[NSColor textColor]];
        }
        [[NSColor controlBackgroundColor] set];
    }
}

@end

@implementation MMPathCell : NSPathCell
+(Class)pathComponentCellClass{
    return [MMPathComponentCell class];
}
@end


@implementation MMPathComponentCell : NSPathComponentCell
- (void)setURL:(NSURL *)url{
    [super setURL:url];
}
@end

@implementation MMFileBrowser
@synthesize sidebarBackgroundColor;
@synthesize sidebarForegroundColor;

- (void)highlightSelectionInClipRect:(NSRect)theClipRect {
    NSRange    visibleRowIndexes   = [self rowsInRect:theClipRect];
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
    NSUInteger row, endRow = visibleRowIndexes.location + visibleRowIndexes.length;
    
    //file browser row bg (for the arrow, not the cell)
    if ([[NSUserDefaults standardUserDefaults] boolForKey:MMSidebarUseVimThemeKey]){
        [[sidebarBackgroundColor highlightWithLevel:0.7] set];
    } else {
        [[NSColor selectedTextBackgroundColor] set];
    }
    
    for (row = visibleRowIndexes.location; row < endRow; row++)
        if([selectedRowIndexes containsIndex:row]) NSRectFill([self rectOfRow:row]);
}

- (void)drawBackgroundInClipRect:(NSRect)clipRect {
    [self updateColors];
    [super drawBackgroundInClipRect:clipRect];
}

- (void)updateColors {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:MMSidebarUseVimThemeKey]){
        [sidebarForegroundColor set];
        [self setBackgroundColor:sidebarBackgroundColor];
    } else {
        [[NSColor textColor] set];
        [self setBackgroundColor:[NSColor controlBackgroundColor]];
    }
}

- (void)setColorsWithBackground:(NSColor*)bgColor foreground:(NSColor*)fgColor {
    sidebarBackgroundColor = bgColor;
    sidebarForegroundColor = fgColor;
}

- (id)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.refusesFirstResponder = YES;
    }
    
    return self;
}

- (BOOL)becomeFirstResponder {
    if (!self.refusesFirstResponder) {
        [self setNeedsDisplay];
    }
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    self.refusesFirstResponder = YES;
    [self setNeedsDisplay];
    return YES;
}

- (void)makeFirstResponder {
    self.refusesFirstResponder = NO;
    [[self window] makeFirstResponder:self];
}

- (void)cancelOperation:(id)sender {
    // Pressing Esc will select the next key view, which should be the text view
    [[self window] selectNextKeyView:nil];
}

- (void)mouseDown:(NSEvent *)event {
    NSInteger row = [self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    MMFileBrowserFSItem *item = [self itemAtRow:row];
    
    if (![item isLeaf] && ![self isItemExpanded:item]) {
        BOOL recursive = (event.modifierFlags & NSAlternateKeyMask) == NSAlternateKeyMask;
        [(id<MMFileBrowserDelegate>)self.delegate fileBrowserWillExpand:self
                                                                   item:item
                                                              recursive:recursive];
    }
    
    NSInteger before = self.selectedRow;
    
    [super mouseDown:event];
    
    // In case the item is not a directory and was already selected, then force
    // send the ‘selection did change’ delegate messages.
    if (event.clickCount == 1 && self.selectedRow == before && [item isLeaf]) {
        [self sendSelectionChangedNotification];
    }
}

- (NSEvent *)keyEventWithEvent:(NSEvent *)event character:(NSString *)character code:(unsigned short)code {
    return [NSEvent keyEventWithType:event.type
                            location:event.locationInWindow
                       modifierFlags:event.modifierFlags
                           timestamp:event.timestamp
                        windowNumber:event.windowNumber
                             context:event.context
                          characters:character
         charactersIgnoringModifiers:character
                           isARepeat:event.isARepeat
                             keyCode:code];
}

- (void)sendSelectionChangedNotification {
    [(id<MMFileBrowserDelegate>)self.delegate outlineViewSelectionIsChanging:nil];
    [(id<MMFileBrowserDelegate>)self.delegate outlineViewSelectionDidChange:nil];
}

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == ENTER_KEY_CODE && (event.modifierFlags & NSControlKeyMask)) {
        //ctrl-enter opens context menu
        NSMenu *menu = [(id<MMFileBrowserDelegate>)self.delegate menuForRow:self.selectedRow];
        NSPoint location = [self rectOfRow:self.selectedRow].origin;
        location.x -= menu.size.width;
        [menu popUpMenuPositioningItem:[menu itemAtIndex:0]
                            atLocation:location
                                inView:self];
        return;
    } else if (event.keyCode == ENTER_KEY_CODE ||
               event.keyCode == LEFT_KEY_CODE ||
               event.keyCode == RIGHT_KEY_CODE) {
        [self sendSelectionChangedNotification];
        return;
    } else if (event.keyCode != TAB_KEY_CODE && event.keyCode != ESCAPE_KEY_CODE
               && event.keyCode != LEFT_KEY_CODE && event.keyCode != RIGHT_KEY_CODE
               && event.keyCode != DOWN_KEY_CODE && event.keyCode != UP_KEY_CODE) {
        switch ([[event.characters uppercaseString] characterAtIndex:0]) {
            case 'H':
                LEFT_KEY_CHAR = [NSString stringWithFormat:@"%C", (unichar)0xf702];
                event = [self keyEventWithEvent:event character:LEFT_KEY_CHAR code:LEFT_KEY_CODE];
                break;
            case 'L':
                RIGHT_KEY_CHAR = [NSString stringWithFormat:@"%C", (unichar)0xf703];
                event = [self keyEventWithEvent:event character:RIGHT_KEY_CHAR code:RIGHT_KEY_CODE];
                break;
            case 'J':
                DOWN_KEY_CHAR = [NSString stringWithFormat:@"%C", (unichar)0xf701];
                event = [self keyEventWithEvent:event character:DOWN_KEY_CHAR code:DOWN_KEY_CODE];
                break;
            case 'K':
                UP_KEY_CHAR = [NSString stringWithFormat:@"%C", (unichar)0xf700];
                event = [self keyEventWithEvent:event character:UP_KEY_CHAR code:UP_KEY_CODE];
                break;
            case 'T':
                [(id<MMFileBrowserDelegate>)self.delegate openSelectedFilesInCurrentWindowWithLayout:MMLayoutTabs];
                event = nil;
                break;
            case 'I':
                [(id<MMFileBrowserDelegate>)self.delegate openSelectedFilesInCurrentWindowWithLayout:MMLayoutHorizontalSplit];
                event = nil;
                break;
            case 'S':
                [(id<MMFileBrowserDelegate>)self.delegate openSelectedFilesInCurrentWindowWithLayout:MMLayoutVerticalSplit];
                event = nil;
                break;
            default:
                event = nil;
                break;
        }
    }
    
    if (event != nil) {
        [super keyDown:event];
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSInteger row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
    if ([self numberOfSelectedRows] <= 1) {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
    return [(id<MMFileBrowserDelegate>)self.delegate menuForRow:row];
}

- (void)expandParentsOfItem:(id)item {
    NSArray *parents = [item parents];
    NSEnumerator *e = [parents reverseObjectEnumerator];
    
    // expand root node
    [self expandItem:nil];
    
    id parent;
    while((parent = [e nextObject])) {
        if(![self isExpandable:parent])
            break;
        if(![self isItemExpanded:parent])
            [self expandItem: parent];
    }
}

- (void)selectItem:(id)item {
    NSInteger itemIndex = [self rowForItem:item];
    if(itemIndex < 0) {
        [self expandParentsOfItem:item];
        itemIndex = [self rowForItem: item];
        if(itemIndex < 0)
            return;
    }
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
    [self scrollRowToVisible:itemIndex];
}

@end

