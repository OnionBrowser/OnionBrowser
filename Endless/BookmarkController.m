#import "AppDelegate.h"
#import "Bookmark.h"
#import "BookmarkController.h"

@implementation BookmarkController

AppDelegate *appDelegate;
UIBarButtonItem *addItem;
UIBarButtonItem *leftItem;

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	self.title = @"Bookmarks";
	self.navigationItem.rightBarButtonItem = addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem:)];
	self.navigationItem.leftBarButtonItem = leftItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
	
	UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
	lpgr.minimumPressDuration = 0.75f;
	lpgr.delegate = self;
	[[self tableView] addGestureRecognizer:lpgr];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[Bookmark persistList];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[Bookmark list] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (self.embedded)
		return @"Bookmarks";
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
	if (self.embedded && [view isKindOfClass:[UITableViewHeaderFooterView class]]) {
		UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
		int buttonSize = tableViewHeaderFooterView.frame.size.height - 8;
		
		UIButton *b = [[UIButton alloc] init];
		[b setFrame:CGRectMake(tableViewHeaderFooterView.frame.size.width - buttonSize - 6, 3, buttonSize, buttonSize)];
		[b setBackgroundColor:[UIColor lightGrayColor]];
		[b setTitle:@"X" forState:UIControlStateNormal];
		[[b titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
		[[b layer] setCornerRadius:buttonSize / 2];
		[b setClipsToBounds:YES];
		
		[b addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
		
		[tableViewHeaderFooterView addSubview:b];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bookmark"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"boomark"];

	Bookmark *b = [[Bookmark list] objectAtIndex:indexPath.row];
	if (b != nil) {
		cell.textLabel.text = b.name;
		cell.detailTextLabel.text = b.urlString;
	}
	
	[cell setShowsReorderControl:YES];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Bookmark *bookmark = [Bookmark list][[indexPath row]];
	
	if (self.embedded)
		[[appDelegate webViewController] prepareForNewURLFromString:[bookmark urlString]];
	else {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Edit Bookmark" message:@"Enter the details of the URL to bookmark:" preferredStyle:UIAlertControllerStyleAlert];
		[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.placeholder = @"URL";
			textField.text = bookmark.urlString;
		}];
		[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.placeholder = @"Page Name (leave blank to use URL)";
			textField.text = bookmark.name;
		}];
		
		UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			UITextField *url = alertController.textFields[0];
			bookmark.urlString = [url text];
			
			UITextField *name = alertController.textFields[1];
			bookmark.name = [name text];
			
			[self.tableView reloadData];
		}];
		
		UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
		[alertController addAction:cancelAction];
		[alertController addAction:okAction];
		
		[self presentViewController:alertController animated:YES completion:nil];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[[Bookmark list] removeObjectAtIndex:[indexPath row]];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
	Bookmark *s = [Bookmark list][[sourceIndexPath row]];
	[[Bookmark list] removeObjectAtIndex:[sourceIndexPath row]];
	[[Bookmark list] insertObject:s atIndex:[destinationIndexPath row]];
}

- (void)addItem:sender
{
	UIAlertController *uiac = [Bookmark addBookmarkDialogWithOkCallback:^{
		[self.tableView reloadData];
	}];
	
	[self presentViewController:uiac animated:YES completion:nil];
}

- (void)didLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
	CGPoint p = [gestureRecognizer locationInView:[self tableView]];
	
	NSIndexPath *indexPath = [[self tableView] indexPathForRowAtPoint:p];
	if (gestureRecognizer.state == UIGestureRecognizerStateBegan && indexPath != nil) {
		[[self tableView] setEditing:YES animated:YES];
		
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditing:)];
		self.navigationItem.leftBarButtonItem = nil;
	}
}
	
- (void)doneEditing:sender
{
	[[self tableView] setEditing:NO animated:YES];
	self.navigationItem.rightBarButtonItem = addItem;
	self.navigationItem.leftBarButtonItem = leftItem;
}

- (void)close
{
	[self removeFromParentViewController];
	[[self view] removeFromSuperview];
}

@end
