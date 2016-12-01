//
//  Bridge.m
//  OnionBrowser
//
//  Created by Mike Tigas on 9/9/12.
//
//

#import "Bridge.h"
#import "AppDelegate.h"

@implementation Bridge

@dynamic conf;

+(NSString *) defaultObfs4 {
	NSString *defaultLines = @"obfs4 154.35.22.10:9332 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
	obfs4 198.245.60.50:443 752CF7825B3B9EA6A98C83AC41F7099D67007EA5 cert=xpmQtKUqQ/6v5X7ijgYE/f03+l2/EuQ1dexjyUhh16wQlu/cpXUGalmhDIlhuiQPNEKmKw iat-mode=0\n\
	obfs4 192.99.11.54:443 7B126FAB960E5AC6A629C729434FF84FB5074EC2 cert=VW5f8+IBUWpPFxF+rsiVy2wXkyTQG7vEd+rHeN2jV5LIDNu8wMNEOqZXPwHdwMVEBdqXEw iat-mode=0\n\
	obfs4 109.105.109.165:10527 8DFCD8FB3285E855F5A55EDDA35696C743ABFC4E cert=Bvg/itxeL4TWKLP6N1MaQzSOC6tcRIBv6q57DYAZc3b2AzuM+/TfB7mqTFEfXILCjEwzVA iat-mode=1\n\
	obfs4 83.212.101.3:50001 A09D536DD1752D542E1FBB3C9CE4449D51298239 cert=lPRQ/MXdD1t5SRZ9MquYQNT9m5DV757jtdXdlePmRCudUU9CFUOX1Tm7/meFSyPOsud7Cw iat-mode=0\n\
	obfs4 109.105.109.147:13764 BBB28DF0F201E706BE564EFE690FE9577DD8386D cert=KfMQN/tNMFdda61hMgpiMI7pbwU1T+wxjTulYnfw+4sgvG0zSH7N7fwT10BI8MUdAD7iJA iat-mode=2\n\
	obfs4 154.35.22.11:7920 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
	obfs4 154.35.22.12:80 00DC6C4FA49A65BD1472993CF6730D54F11E0DBB cert=N86E9hKXXXVz6G7w2z8wFfhIDztDAzZ/3poxVePHEYjbKDWzjkRDccFMAnhK75fc65pYSg iat-mode=0\n\
	obfs4 154.35.22.13:443 FE7840FE1E21FE0A0639ED176EDA00A3ECA1E34D cert=fKnzxr+m+jWXXQGCaXe4f2gGoPXMzbL+bTBbXMYXuK0tMotd+nXyS33y2mONZWU29l81CA iat-mode=0\n\
	obfs4 154.35.22.10:80 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
	obfs4 154.35.22.10:443 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
	obfs4 154.35.22.11:443 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
	obfs4 154.35.22.11:80 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
	obfs4 154.35.22.9:7013 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0\n\
	obfs4 154.35.22.9:80 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0\n\
	obfs4 154.35.22.9:443 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0\n\
	obfs4 154.35.22.12:4148 00DC6C4FA49A65BD1472993CF6730D54F11E0DBB cert=N86E9hKXXXVz6G7w2z8wFfhIDztDAzZ/3poxVePHEYjbKDWzjkRDccFMAnhK75fc65pYSg iat-mode=0\n\
	obfs4 154.35.22.13:6041 FE7840FE1E21FE0A0639ED176EDA00A3ECA1E34D cert=fKnzxr+m+jWXXQGCaXe4f2gGoPXMzbL+bTBbXMYXuK0tMotd+nXyS33y2mONZWU29l81CA iat-mode=0\n\
	obfs4 192.95.36.142:443 CDF2E852BF539B82BD10E27E9115A31734E378C2 cert=qUVQ0srL1JI/vO6V6m/24anYXiJD3QP2HgzUKQtQ7GRqqUvs7P+tG43RtAqdhLOALP7DJQ iat-mode=1";
	NSMutableArray *lines = [NSMutableArray arrayWithArray:[defaultLines componentsSeparatedByCharactersInSet:
															[NSCharacterSet characterSetWithCharactersInString:@"\n"]
															]];

	// Randomize order of the bridge lines.
	for (int x = 0; x < [lines count]; x++) {
		int randInt = (arc4random() % ([lines count] - x)) + x;
		[lines exchangeObjectAtIndex:x withObjectAtIndex:randInt];
	}
	return [lines componentsJoinedByString:@"\n"];
	// Take a subset of the randomized lines and return it as a new string of bridge lines.
	//NSArray *subset = [lines subarrayWithRange:(NSRange){0, 5}];
	//return [subset componentsJoinedByString:@"\n"];
}
+(NSString *) defaultMeekAmazon {
	return @"meek_lite 0.0.2.0:2 B9E7141C594AF25699E0079C1F0146F409495296 url=https://d2zfqthxsdq309.cloudfront.net/ front=a0.awsstatic.com";
}
+(NSString *) defaultMeekAzure {
	return @"meek_lite 0.0.2.0:3 A2C13B7DFCAB1CBF3A884B6EB99A98067AB6EF44 url=https://az786092.vo.msecnd.net/ front=ajax.aspnetcdn.com";
}

+ (void)updateBridgeLines:(NSString *)bridgeLines {
	[Bridge clearBridges];

	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *ctx = appDelegate.managedObjectContext;

	NSString *txt = [bridgeLines stringByReplacingOccurrencesOfString:@"[ ]+"
														   withString:@" "
															  options:NSRegularExpressionSearch
																range:NSMakeRange(0, bridgeLines.length)];

	for (NSString *line in [txt componentsSeparatedByString:@"\n"]) {
		NSString *newLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([newLine isEqualToString:@""]) {
			// skip empty lines
		} else {
			Bridge *newBridge = [NSEntityDescription insertNewObjectForEntityForName:@"Bridge" inManagedObjectContext:ctx];
			[newBridge setConf:newLine];
			NSError *err = nil;
			if (![ctx save:&err]) {
				NSLog(@"Save did not complete successfully. Error: %@", [err localizedDescription]);
			}
		}
	}
}
+ (void)clearBridges {
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	NSManagedObjectContext *ctx = appDelegate.managedObjectContext;

	NSFetchRequest *request = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
	[request setEntity:entity];

	NSArray *results = [ctx executeFetchRequest:request error:nil];
	if (results == nil) {}
	for (Bridge *bridge in results) {
		[ctx deleteObject:bridge];
	}
	[ctx save:nil];
}


@end
