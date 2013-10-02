(define (script-fu-lcd-sim img draw)
	(let*
		(
			(imgWidth (car (gimp-image-width img)))
			(imgHeight (car (gimp-image-height img)))
			(column 0)
			(rLayer)
			(gLayer)
			(bLayer)
			(subpixel)
			(mergeLayer)
			(selChannel)
		)
		(gimp-image-undo-group-start img)
		
		; stretch the image 3x wide so each RGB sub-pixel gets its own column
		(gimp-context-set-interpolation INTERPOLATION-NONE)
		(gimp-image-scale img (* 3 imgWidth) imgHeight)
		
		; create a new channel to store selection info
		(set! selChannel (car (gimp-channel-new img (* 3 imgWidth) imgHeight "sel" 100 '(0 0 0))))
		(gimp-image-insert-channel img selChannel 0 0)
		(gimp-image-set-active-channel img selChannel)
		
		; add the first column to the selection channel
		(gimp-image-select-rectangle img CHANNEL-OP-REPLACE 0 0 1 imgHeight)
		(gimp-context-set-default-colors)
		(gimp-edit-fill selChannel WHITE-FILL)
		
		; repeat the selected column every 3 pixels across the image
		(fill-channel selChannel 3 (* 3 imgWidth))
		
		; create the red layer from the selection channel and remove the now-unneeded channel
		(gimp-image-select-color img CHANNEL-OP-REPLACE selChannel '(255 255 255))
		(gimp-image-remove-channel img selChannel)
		(gimp-edit-copy draw)
		(set! rLayer (car (gimp-edit-paste draw 1)))
		(gimp-floating-sel-to-layer rLayer)
		(gimp-item-set-name rLayer "red")
		(gimp-selection-none img)
		
		; copy and translate the green layer from the red layer
		(set! gLayer (car (gimp-layer-copy rLayer TRUE)))
		(gimp-item-set-name gLayer "green")
		(gimp-layer-translate gLayer 1 0)
		(gimp-image-insert-layer img gLayer 0 0)
		
		; copy and translate the blue layer from the green layer
		(set! bLayer (car (gimp-layer-copy gLayer TRUE)))
		(gimp-item-set-name bLayer "blue")
		(gimp-layer-translate bLayer 1 0)
		(gimp-image-insert-layer img bLayer 0 0)
		
		; filter color levels for each layer
		(filter-levels rLayer HISTOGRAM-RED)
		(filter-levels gLayer HISTOGRAM-GREEN)
		(filter-levels bLayer HISTOGRAM-BLUE)

		; merge new layers
		(set! mergeLayer (car (gimp-image-merge-down img bLayer EXPAND-AS-NECESSARY)))
		(set! mergeLayer (car (gimp-image-merge-down img mergeLayer EXPAND-AS-NECESSARY)))
		
		; fix image scale
		(gimp-image-scale img (* 3 imgWidth) (* 3 imgHeight))
		
		; copy and save layer to preserve a copy of the raw LCD sub-pixels
		(set! subpixel (car (gimp-layer-copy mergeLayer TRUE)))
		(gimp-item-set-name subpixel "raw subpixels")
		(gimp-image-insert-layer img subpixel 0 1)
		
		; blur and fix levels
		(plug-in-gauss-rle RUN-NONINTERACTIVE img mergeLayer 4.0 1 0)
		(fix-levels mergeLayer)
		
		(gimp-item-set-name mergeLayer "simulated LCD")
		
		(gimp-image-undo-group-end img)
	)
)

(define (fill-channel ch x width)
	(if (> x width)
		()
		(let*
			(
				(copy (car (gimp-channel-copy ch)))
			)
			(gimp-channel-combine-masks ch copy CHANNEL-OP-ADD x 0)
			(fill-channel ch (* 2 x) width)
		)
	)
)

(define (filter-levels layer keepColor)
	(if (= keepColor HISTOGRAM-RED) () (gimp-levels layer HISTOGRAM-RED 0 255 1.0 0 0) )
	(if (= keepColor HISTOGRAM-GREEN) () (gimp-levels layer HISTOGRAM-GREEN 0 255 1.0 0 0) )
	(if (= keepColor HISTOGRAM-BLUE) () (gimp-levels layer HISTOGRAM-BLUE 0 255 1.0 0 0) )
)

(define (fix-levels layer)
	(gimp-levels layer HISTOGRAM-RED   0 85 1.0 0 255)
	(gimp-levels layer HISTOGRAM-GREEN 0 85 1.0 0 255)
	(gimp-levels layer HISTOGRAM-BLUE  0 85 1.0 0 255)
)

(script-fu-register
    "script-fu-lcd-sim"                         ;func name
    "LCD simulation"                            ;menu label
    "Simulate LCD subpixel effects for displays
	with large pixel pitch."                    ;description
    "Timothy Van Ruitenbeek"                    ;author
    "MindTribe Product Engineering, Inc."       ;copyright notice
    "2013-09-27"                                ;date created
    "*"                     ;image type that the script works on
    SF-IMAGE       "Input image" 0
    SF-DRAWABLE    "Input drawable" 0
  )
  (script-fu-menu-register "script-fu-lcd-sim" "<Image>/Filters")