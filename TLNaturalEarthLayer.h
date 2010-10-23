//
//  TLNaturalEarthLayer.h
//  Mercatalog
//
//  Created by Jon Hjelle on 9/17/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLMapLayer.h"

@class TLTileset;

@interface TLNaturalEarthLayer : TLMapLayer {
@private
	TLTileset* tileset;
}

@end
