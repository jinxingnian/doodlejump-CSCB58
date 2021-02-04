#####################################################################
#
# CSCB58 Fall 2020 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Name Xingnian Jin, Student Number 1004803787
#
# Bitmap Display Configuration:
# - Unit width in pixels: 16					     
# - Unit height in pixels: 16
# - Display width in pixels: 512
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 5
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 
# Milestone 4:
# 	- scoreboard / score count
# 	- Dynamic increase in difficulty (speed increase as each level)
# Milestone 5:
# 	- Realistic physics
# 	- Fancier graphics (start, game over, pause screen)
# 	- Dynamic on-screen notification
#
# Link to video demonstration for final submission:
# - https://play.library.utoronto.ca/b8915f826998e8ee1fed243ad995befd
#
# Any additional information that the TA needs to know:
# - Control wise: 's' to start or restart, 'j' and 'k' to move left/right, 'p' to pause or resume
# - Bitmap consist of Rows (1-32) and blocks (1-32), 1 block consists of 4 bytes
# - Thank you for the effort of this semester! :)
#
#####################################################################

.data
	displayAddress:	.word	0x10008000
	scoreAddress: .word 0x10008074
	
	
	SKY_COLOR: .word 0xf9e2cb
	STAIR_COLOR: .word 0x66cdaa
	CHAR_COLOR: .word 0xff6ba3
	GAME_OVER_COLOR: .word 0x20b2aa
	SCORE_COLOR: .word 0x420420
	POPUP_COLOR: .word 0xf6b5c9
	
	charPos: .word 0
	jumpTimes: .word 0
	fallTimes: .word 0
	jumpOrFall: .word 0 # 0 for jump, 1 for fall
	leftOrRight: .word 0 # 1 for left, 2 for right
	
	score: .word 0 # score of player, increse 1 every passed level
	sleepTime: .word 80 # used to control the speed of the character
	
	randStairArray: .space 96
	randStairArraySize: .word 24 # stair length 6
	
	stair1Offset: .word 0 # offset for random stair generator
	stair2Offset: .word 0
	stair3Offset: .word 0
	
	
	bottomArray: .space 128
	topArray: .space 128
	
	gameOver: .asciiz "Game Over!\n"
	restart: .asciiz "Press S to restart, E to exit!\n"
	
.text
start_screen:
	# Draw start screen at beginning
	jal draw_background
	jal draw_game_title
	
	start_loop:
		lw $t0, 0xffff0000
		beq $t0, 1, start_detection
		j start_loop
	start_detection:
		lw $t0, 0xffff0004
		# see if user pressed space button
		beq $t0, 0x73, start_action
		j start_loop
	start_action:
		j main
	
main:
	# initialize position for random stairs
	jal random_stair_generator
	# initialize bottom array
	jal save_bottom_array
	# initialize top array
	jal save_top_array
	
	# initialize character position
	# char loctes at row 25, block stair1Offset*4
	# formula: (4*32)*25 + (stair1Offset+3)*4
	lw $t0, displayAddress
	lw $t1, stair1Offset
	addi $t1, $t1, 3
	mul $t1, $t1, 4
	addi $t1, $t1, 3200
	add $t0, $t0, $t1
	sw $t0, charPos
	
	# reset the jumpTimes, for new level
	li $t0, 0
	sw $t0, jumpTimes
	
	loop:
		# Detect keyboard input --------------------------------------------------------------
		press_detection:
		
		lw $t0, 0xffff0000
		beq $t0, 1, key_detection
		j update_pos
		
		
		
		key_detection:
		
		lw $t0, 0xffff0004
		# see if the key pressed is 'j'
		beq $t0, 0x6a, left_action
		# see if the key pressed is 'k'
		beq $t0, 0x6b, right_action
		# If key pressed is 'p', pause screen
		beq $t0, 0x70, pause_screen
		
		j update_pos
		
		pause_screen:
			jal draw_pause
			
			pause_loop:
			lw $t0, 0xffff0000
			beq $t0, 1, pause_detection
			j pause_loop
			pause_detection:
				lw $t0, 0xffff0004
				# see if user pressed space button
				beq $t0, 0x70, pause_action
				j pause_loop
			pause_action:
				j update_pos
		
		left_action:
		
		# change the character mode to move_left for rendering
		la $a0, leftOrRight
		li $t0, 1
		sw $t0, 0($a0)
		
		jal move_left
		j update_pos
		
		
		
		right_action:
		
		# change the character mode to move_right for rendering
		la $a0, leftOrRight
		li $t0, 2
		sw $t0, 0($a0)
		
		jal move_right
		j update_pos
		
		
		
		
		
		# update position --------------------------------------------------------------------
		update_pos:
			lw $t0, jumpOrFall
			
			beq $t0, 0, jump_action
			beq $t0, 1, fall_action
		
		jump_action:
			jal jump
			lw $t0, jumpTimes
			
			beq $t0, 15, switch
			j next_level_detection
		fall_action:
			jal fall
			
			# collision detection with platform
			la $a0, randStairArray
			
			lw $t0, randStairArraySize
			li $t1, 0
			lw $t2, charPos
			
			# Improvement: make game easier, include two 'feet' of character in collision detection
			addi $t4, $t2, 4
			addi $t5, $t2, -4
			
			collision_detection:
				beq $t1, $t0, game_over_detection_prep
				
				lw $t3, 0($a0) # t3 is current platform block
				beq $t3, $t2, switch
				beq $t3, $t4, switch
				beq $t3, $t5, switch
				
				addi $t1, $t1, 1 # counter++
				
				addi $a0, $a0, 4 # address++
				
				j collision_detection
			
			game_over_detection_prep:	
			# game over detection with lower boundary
			la $a0, bottomArray
			li $t0, 32 # array size limit
			li $t1, 0 # counter
			lw $t2, charPos
			game_over_detection:
				beq $t1, $t0, render
				
				lw $t3, 0($a0) # t3 is current platform block
				beq $t3, $t2, Exit
				
				addi $t1, $t1, 1 # counter++
				addi $a0, $a0, 4 # address++
				
				j game_over_detection
		next_level_detection:
			# next level detection with roof
			la $a0, topArray
			li $t0, 32 # array size limit
			li $t1, 0 # counter
			lw $t2, charPos
			next_level_loop:
				beq $t1, $t0, render
				
				lw $t3, 0($a0) # t3 is the current roof block
				beq $t3, $t2, increment_score
				
				addi $t1, $t1, 1 # counter++
				addi $a0, $a0, 4 # address++
				
				j next_level_loop
		
		increment_score:
			lw $t0, score
			addi $t0, $t0, 1
			sw $t0, score
			
			# increment character speed (reduce sleep time)
			# if sleepTime > 35
			lw $t0, sleepTime
			
			beq $t0, 35, keep_speed
			addi $t0, $t0, -5
			sw $t0, sleepTime
			
			keep_speed:
			
			# on-screen popup notification
			# randomly display popup
			li $v0, 42
			li $a0, 0
			li $a1, 2
			syscall
			
			beq $a0, 0, popup1
			beq $a0, 1, popup2
			
			popup1:
			jal draw_popup1
			j sleep_after_pop
			popup2:
			jal draw_popup2
			j sleep_after_pop
			
			sleep_after_pop:
			# sleep
			li $v0, 32
			la $a0, 500
			syscall
			
			j main
			
		switch:
			jal switch_jump_fall
			j render
			
		
		# draw the screen----------------------------------------------------------------------
		render:
		jal draw_background
		jal draw_stairs
		
		# render character based on its status: left, right
		lw $t0, leftOrRight
		beq $t0, 1, render_left
		beq $t0, 2, render_right

		render_left:
		jal draw_char_left
		j render_score
		
		render_right:
		jal draw_char_right
		j render_score
		
		render_score:
		jal display_score
		j sleep
		
		
		# sleep -----------------------------------------------------------------------------------
		sleep:
		
		# realistic physics: 
		# Theory: jumpTimes range from 0-15, fallTimes range from 0-32
		# When jumping up, character slows down, it means sleepTime longer, so sleepTime + jumpTimes
		# When falling down, character speed up, it means sleepTime shorter, so sleepTime - fallTimes
		# Note: character can only jump or fall, so one of jumpTimes/fallTimes must be 0 at every time,
		# So formula for sleepTime: sleepTime + jumpTimes - fallTimes
		li $v0, 32
		lw $a0, sleepTime # sleep miliseconds
		lw $t0, jumpTimes
		add $a0, $a0, $t0
		lw $t0, fallTimes
		sub $a0, $a0, $t0
		syscall
		j go_back
		
		# go back to loop -------------------------------------------------------------------------
		go_back:
		j loop

draw_popup1:
	# popup "YAY!"
	lw $a0, displayAddress
	addi $a0, $a0, 1952
	lw $t0, POPUP_COLOR
	
	# draw Y
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 8($a0)
	sw $t0, 136($a0)
	sw $t0, 260($a0)
	sw $t0, 388($a0)
	sw $t0, 516($a0)
	# draw A
	addi $a0, $a0, 16
	sw $t0, 4($a0)
	sw $t0, 128($a0)
	sw $t0, 136($a0)
	sw $t0, 256($a0)
	sw $t0, 260($a0)
	sw $t0, 264($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 392($a0)
	sw $t0, 520($a0)
	# draw Y
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 8($a0)
	sw $t0, 136($a0)
	sw $t0, 260($a0)
	sw $t0, 388($a0)
	sw $t0, 516($a0)
	# draw !
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 512($a0)
	
	jr $ra

draw_popup2:
	# popup "WOW!"
	lw $a0, displayAddress
	addi $a0, $a0, 1952
	lw $t0, POPUP_COLOR
	
	# char W
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 388($a0)
	sw $t0, 8($a0)
	sw $t0, 136($a0)
	sw $t0, 264($a0)
	sw $t0, 392($a0)
	sw $t0, 520($a0)
	# char O
	addi $a0, $a0, 16
	sw $t0, 4($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 516($a0)
	sw $t0, 392($a0)
	sw $t0, 264($a0)
	sw $t0, 136($a0)
	# char W
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 388($a0)
	sw $t0, 8($a0)
	sw $t0, 136($a0)
	sw $t0, 264($a0)
	sw $t0, 392($a0)
	sw $t0, 520($a0)
	# char !
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 512($a0)
	
	jr $ra
	
	
draw_game_title:
	# draw game title "DOODLE JUMP"
	lw $t0, GAME_OVER_COLOR
	lw $a0, displayAddress
	addi $a0, $a0, 1300 # row 10 block 5
	
	# char D
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 4($a0)
	sw $t0, 516($a0)
	sw $t0, 136($a0)
	sw $t0, 264($a0)
	sw $t0, 392($a0)
	# char --- (dash)
	addi $a0, $a0, 16
	sw $t0, 256($a0)
	sw $t0, 260($a0)
	sw $t0, 264($a0)
	# char J
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 4($a0)
	sw $t0, 8($a0)
	sw $t0, 132($a0)
	sw $t0, 260($a0)
	sw $t0, 388($a0)
	sw $t0, 516($a0)
	sw $t0, 512($a0)
	# char U
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 8($a0)
	sw $t0, 128($a0)
	sw $t0, 136($a0)
	sw $t0, 256($a0)
	sw $t0, 264($a0)
	sw $t0, 384($a0)
	sw $t0, 392($a0)
	sw $t0, 512($a0)
	sw $t0, 516($a0)
	sw $t0, 520($a0)
	# char M
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 132($a0)
	sw $t0, 8($a0)
	sw $t0, 136($a0)
	sw $t0, 264($a0)
	sw $t0, 392($a0)
	sw $t0, 520($a0)
	# char P
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 4($a0)
	sw $t0, 260($a0)
	sw $t0, 136($a0)
	
	jr $ra

draw_pause:
	# draw "pause" screen
	lw $a0, displayAddress
	# row 15 block 8
	# formula: 128*15 + 4*8
	addi $a0, $a0, 1952
	lw $t0, GAME_OVER_COLOR
	
	# char P
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 4($a0)
	sw $t0, 260($a0)
	sw $t0, 136($a0)
	# char A
	addi $a0, $a0, 16
	sw $t0, 4($a0)
	sw $t0, 128($a0)
	sw $t0, 136($a0)
	sw $t0, 256($a0)
	sw $t0, 260($a0)
	sw $t0, 264($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 392($a0)
	sw $t0, 520($a0)
	# char L
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 516($a0)
	sw $t0, 520($a0)
	# char S
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 4($a0)
	sw $t0, 8($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 260($a0)
	sw $t0, 264($a0)
	sw $t0, 392($a0)
	sw $t0, 520($a0)
	sw $t0, 516($a0)
	sw $t0, 512($a0)
	# char E
	addi $a0, $a0, 16
	sw $t0, 0($a0)
	sw $t0, 4($a0)
	sw $t0, 8($a0)
	sw $t0, 128($a0)
	sw $t0, 256($a0)
	sw $t0, 260($a0)
	sw $t0, 264($a0)
	sw $t0, 384($a0)
	sw $t0, 512($a0)
	sw $t0, 516($a0)
	sw $t0, 520($a0)
	
	jr $ra
	
draw_background:

	# $t0 = display address
	lw $t0, displayAddress
	# $t1 = bg color
	lw $t1, SKY_COLOR
	
	
	bg_loop:
		sw $t1, 0($t0)
		addi $t0, $t0, 4
		
		# if last block is reached, return
		beq $t0, 0x10009000, bg_exit
		
		j bg_loop
	bg_exit:
		jr $ra


random_stair_generator:
	# generates 3 offset range [0,26] for three stairs (6 space for stairs)
	
	# stair 1
	li $v0, 42
	li $a0, 0
	li $a1, 24
	syscall
	
	sw $a0, stair1Offset
	
	# stair 2
	li $v0, 42
	li $a0, 0
	li $a1, 24
	syscall
	
	sw $a0, stair2Offset
	
	# stair 3
	li $v0, 42
	li $a0, 0
	li $a1, 24
	syscall
	
	sw $a0, stair3Offset
	
	jr $ra

draw_stairs:
	
	# Draw 3 random generated stairs
	
	# initialize global var: 
	la $a2, randStairArray # $a2 = address of stairs, used for collision detection
	
	# generate random stair1, base stair row #30, col range [0,26]
	# formula: (32*4)*29 + (randNumber)*4
	rand_st1_start:
	lw $t0, displayAddress
	lw $t1, STAIR_COLOR
	
	lw $t2, stair1Offset # $t2 set to random generated offset of stair
	mul $t2, $t2, 4 # (randNumber) * 4
	addi $t2, $t2, 3712 # $t2 is the offset
	add $t0, $t0, $t2 # $t0 set to the first block for stair
	
	addi $t2, $t0, 32 # $t2 is now the end block of stair
	
	rand_st1_loop:
		sw $t1, 0($t0) # draw block
		sw $t0, 0($a2) # save to the randStairArray
		
		addi $t0, $t0, 4 # increment block address
		addi $a2, $a2, 4 # increment randStairArray pointer
		
		beq $t0, $t2, rand_st2_start
		j rand_st1_loop
	
	# generate random stair2, row 20, col range [0,26]
	# formula: (32*4)*19 + (randNumber)*4
	rand_st2_start:
	lw $t0, displayAddress
	lw $t1, STAIR_COLOR
	
	lw $t2, stair2Offset # $t2 set to random generated offset of stair
	mul $t2, $t2, 4 # (randNumber) * 4
	addi $t2, $t2, 2432 # $t2 is the offset
	add $t0, $t0, $t2 # $t0 set to the first block for stair
	
	addi $t2, $t0, 32 # $t2 is now the end block of stair
	
	rand_st2_loop:
		sw $t1, 0($t0) # draw block
		sw $t0, 0($a2) # save to the randStairArray
		
		addi $t0, $t0, 4 # increment block address
		addi $a2, $a2, 4 # increment randStairArray pointer
		
		beq $t0, $t2, rand_st3_start
		j rand_st2_loop
		
		
	# generate random stair3, row 10, col range [0,26]
	# formula: (32*4)*9 + (randNumber)*4
	rand_st3_start:
	lw $t0, displayAddress
	lw $t1, STAIR_COLOR
	
	lw $t2, stair3Offset # $t2 set to random generated offset of stair
	mul $t2, $t2, 4 # (randNumber) * 4
	addi $t2, $t2, 1152 # $t2 is the offset
	add $t0, $t0, $t2 # $t0 set to the first block for stair
	
	addi $t2, $t0, 32 # $t2 is now the end block of stair
	
	rand_st3_loop:
		sw $t1, 0($t0) # draw block
		sw $t0, 0($a2) # save to the randStairArray
		
		addi $t0, $t0, 4 # increment block address
		addi $a2, $a2, 4 # increment randStairArray pointer
		
		beq $t0, $t2, rand_st_exit
		j rand_st3_loop
	
	rand_st_exit:
	jr $ra
	
draw_char_left:
	
	# draw character when press 'j' key
	lw $t0, charPos
	lw $t1, CHAR_COLOR
	
	# draw legs
	sw $t1, -4($t0)
	sw $t1, 4($t0)
	
	# draw body
	sw $t1, -128($t0)
	sw $t1, -256($t0)
	
	# draw hand
	sw $t1, -260($t0)
	
	# draw head
	sw $t1, -384($t0)
	
	jr $ra

draw_char_right:
	
	# draw character when press 'k' key
	lw $t0, charPos
	lw $t1, CHAR_COLOR
	
	# draw legs
	sw $t1, -4($t0)
	sw $t1, 4($t0)
	
	# draw body
	sw $t1, -128($t0)
	sw $t1, -256($t0)
	
	# draw hand
	sw $t1, -252($t0)
	
	# draw head
	sw $t1, -384($t0)
	
	jr $ra
	
jump:
	# Character jump for one block
	
	# jump for 1 block up
	lw $t0, charPos
	addi $t0, $t0, -128
	sw $t0, charPos
	
	lw $t0, jumpTimes
	addi $t0, $t0, 1
	sw $t0, jumpTimes
	
	# return
	jr $ra

fall:
	# Character fall down one block
	
	# fall 1 block down
	lw $t0, charPos
	addi $t0, $t0, 128
	sw $t0, charPos
	
	lw $t0, fallTimes
	addi $t0, $t0, 1
	sw $t0, fallTimes
	
	# return
	jr $ra

switch_jump_fall:
	
	# switch from jump to fall or from fall to jump
	
	lw $t0, jumpOrFall
	beq $t0, 0, jumpToFall
	beq $t0, 1, fallToJump
	
	jumpToFall:
		li $t0, 1
		j switch_manipulation
	fallToJump:
		li $t0, 0
		j switch_manipulation
	switch_manipulation:
		sw $t0, jumpOrFall
		li $t0, 0
		sw $t0, jumpTimes
		sw $t0, fallTimes
		jr $ra
		
move_left:
	lw $t0, charPos
	addi $t0, $t0, -4
	sw $t0, charPos
	jr $ra

move_right:
	lw $t0, charPos
	addi $t0, $t0, 4
	sw $t0, charPos
	jr $ra
	
save_bottom_array:
	
	# save address of bottom array to bottomArray for detecting end of game
	la $a0, bottomArray
	lw $t0, displayAddress
	addi $t0, $t0, 4096 # t0 is start block of bottom array
	
	addi $t1, $t0, 128
	
	sav_bot_loop:
		sw $t0, 0($a0) # save to bottomArray
		
		beq $t0, $t1, sav_bot_exit
		
		addi $a0, $a0, 4
		addi $t0, $t0, 4
		
		j sav_bot_loop
		
	sav_bot_exit:
		jr $ra
save_top_array:
	# save address of top array to topArray for detecting next level
	la $a0, topArray
	lw $t0, displayAddress
	
	addi $t1, $t0, 128
	sav_top_loop:
		beq $t0, $t1, sav_top_exit
		
		sw $t0, 0($a0) # save to topArray
		
		addi $a0, $a0, 4
		addi $t0, $t0, 4
		
		j sav_top_loop
	
	sav_top_exit:
		jr $ra
		
draw_number:
	# Set $t0 to the parameter to display (a single number)
	# Set $a0 to be the parameter of display address for the number (left top corner)
	# This uses 16 block display
	
	lw $t1, SCORE_COLOR
	
	beq $t0, 1, draw_1
	beq $t0, 2, draw_2
	beq $t0, 3, draw_3
	beq $t0, 4, draw_4
	beq $t0, 5, draw_5
	beq $t0, 6, draw_6
	beq $t0, 7, draw_7
	beq $t0, 8, draw_8
	beq $t0, 9, draw_9
	beq $t0, 0, draw_0
	
	draw_1:
	sw $t1, 4($a0)
	sw $t1, 128($a0)
	sw $t1, 132($a0)
	sw $t1, 260($a0)
	sw $t1, 388($a0)
	sw $t1, 516($a0)
	sw $t1, 520($a0)
	sw $t1, 512($a0)
	j draw_number_exit
	draw_2:
	sw $t1, 0($a0)
	sw $t1, 4($a0)
	sw $t1, 8($a0)
	sw $t1, 136($a0)
	sw $t1, 264($a0)
	sw $t1, 260($a0)
	sw $t1, 256($a0)
	sw $t1, 384($a0)
	sw $t1, 512($a0)
	sw $t1, 516($a0)
	sw $t1, 520($a0)
	j draw_number_exit
	draw_3:
	sw $t1, 0($a0)
	sw $t1, 4($a0)
	sw $t1, 8($a0)
	sw $t1, 136($a0)
	sw $t1, 264($a0)
	sw $t1, 260($a0)
	sw $t1, 256($a0)
	sw $t1, 392($a0)
	sw $t1, 512($a0)
	sw $t1, 516($a0)
	sw $t1, 520($a0)
	j draw_number_exit
	draw_4:
	sw $t1, 0($a0)
	sw $t1, 128($a0)
	sw $t1, 256($a0)
	sw $t1, 260($a0)
	sw $t1, 264($a0)
	sw $t1, 136($a0)
	sw $t1, 8($a0)
	sw $t1, 392($a0)
	sw $t1, 520($a0)
	j draw_number_exit
	draw_5:
	sw $t1, 0($a0)
	sw $t1, 4($a0)
	sw $t1, 8($a0)
	sw $t1, 128($a0)
	sw $t1, 256($a0)
	sw $t1, 260($a0)
	sw $t1, 264($a0)
	sw $t1, 392($a0)
	sw $t1, 520($a0)
	sw $t1, 516($a0)
	sw $t1, 512($a0)
	j draw_number_exit
	draw_6:
	sw $t1, 8($a0)
	sw $t1, 4($a0)
	sw $t1, 0($a0)
	sw $t1, 128($a0)
	sw $t1, 256($a0)
	sw $t1, 384($a0)
	sw $t1, 512($a0)
	sw $t1, 516($a0)
	sw $t1, 520($a0)
	sw $t1, 392($a0)
	sw $t1, 264($a0)
	sw $t1, 260($a0)
	j draw_number_exit
	draw_7:
	sw $t1, 128($a0)
	sw $t1, 0($a0)
	sw $t1, 4($a0)
	sw $t1, 8($a0)
	sw $t1, 136($a0)
	sw $t1, 264($a0)
	sw $t1, 392($a0)
	sw $t1, 520($a0)
	j draw_number_exit
	draw_8:
	sw $t1, 0($a0)
	sw $t1, 4($a0)
	sw $t1, 8($a0)
	sw $t1, 128($a0)
	sw $t1, 136($a0)
	sw $t1, 256($a0)
	sw $t1, 260($a0)
	sw $t1, 264($a0)
	sw $t1, 384($a0)
	sw $t1, 392($a0)
	sw $t1, 512($a0)
	sw $t1, 516($a0)
	sw $t1, 520($a0)
	j draw_number_exit
	draw_9:
	sw $t1, 0($a0)
	sw $t1, 4($a0)
	sw $t1, 8($a0)
	sw $t1, 128($a0)
	sw $t1, 136($a0)
	sw $t1, 256($a0)
	sw $t1, 260($a0)
	sw $t1, 264($a0)
	sw $t1, 392($a0)
	sw $t1, 512($a0)
	sw $t1, 516($a0)
	sw $t1, 520($a0)
	j draw_number_exit
	draw_0:
	sw $t1, 0($a0)
	sw $t1, 4($a0)
	sw $t1, 8($a0)
	sw $t1, 128($a0)
	sw $t1, 136($a0)
	sw $t1, 256($a0)
	sw $t1, 264($a0)
	sw $t1, 384($a0)
	sw $t1, 392($a0)
	sw $t1, 512($a0)
	sw $t1, 516($a0)
	sw $t1, 520($a0)
	j draw_number_exit
	
	draw_number_exit:
	j display_score_continue

display_score:
	lw $a0, scoreAddress
	# display score initially at line 0 block 29
	# formula: 29*4
	#addi $a0, $a0, 116 # a0 is the parameter for draw_number (address)
	
	lw $t2, score # t2 is score, constantly changing
	display_score_loop:
		
		# get remainder of score/10 (thats what we want to display)
		rem $t0, $t2, 10
		# remove last digit in t2
		div $t2, $t2, 10
		# draw number
		j draw_number
		
		display_score_continue:
		# check if done last digit
		beq $t2, 0, display_exit
		
		# update next digit address -4 block from current
		addi $a0, $a0, -16
		j display_score_loop
	
	display_exit:
	jr $ra


draw_game_over:
	
	# draw the 'game over' character on screen
	lw $t0, displayAddress
	addi $t0, $t0, 1300 # start at row 10 block 5
	lw $t1, GAME_OVER_COLOR
	
	# char G
	sw $t1, 0($t0)
	sw $t1, 124($t0)
	sw $t1, 252($t0)
	sw $t1, 256($t0)
	sw $t1, 384($t0)
	sw $t1, 260($t0)
	# char A
	sw $t1, 264($t0)
	sw $t1, 392($t0)
	sw $t1, 136($t0)
	sw $t1, 268($t0)
	sw $t1, 12($t0)
	sw $t1, 144($t0)
	sw $t1, 272($t0)
	sw $t1, 400($t0)
	# char M
	sw $t1, 20($t0)
	sw $t1, 148($t0)
	sw $t1, 276($t0)
	sw $t1, 404($t0)
	sw $t1, 152($t0)
	sw $t1, 156($t0)
	sw $t1, 28($t0)
	sw $t1, 284($t0)
	sw $t1, 412($t0)
	# char E
	sw $t1, 416($t0)
	sw $t1, 288($t0)
	sw $t1, 160($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	sw $t1, 292($t0)
	sw $t1, 420($t0)
	# char O
	sw $t1, 432($t0)
	sw $t1, 304($t0)
	sw $t1, 176($t0)
	sw $t1, 48($t0)
	sw $t1, 52($t0)
	sw $t1, 436($t0)
	sw $t1, 440($t0)
	sw $t1, 312($t0)
	sw $t1, 184($t0)
	sw $t1, 56($t0)
	# char V
	sw $t1, 60($t0)
	sw $t1, 188($t0)
	sw $t1, 316($t0)
	sw $t1, 448($t0)
	sw $t1, 324($t0)
	sw $t1, 196($t0)
	sw $t1, 68($t0)
	# char E
	sw $t1, 72($t0)
	sw $t1, 200($t0)
	sw $t1, 328($t0)
	sw $t1, 456($t0)
	sw $t1, 460($t0)
	sw $t1, 332($t0)
	sw $t1, 76($t0)
	# char R
	sw $t1, 80($t0)
	sw $t1, 208($t0)
	sw $t1, 336($t0)
	sw $t1, 464($t0)
	sw $t1, 340($t0)
	sw $t1, 84($t0)
	sw $t1, 88($t0)
	sw $t1, 216($t0)
	sw $t1, 472($t0)
	jr $ra

	
Exit:
	# game over screen, waiting for restart or end
	
	li $v0, 4
	la $a0, gameOver
	syscall
	
	li $v0, 4
	la $a0, restart
	syscall
	
	# draw a game over screen
	jal draw_background
	jal draw_game_over
	
	# draw score on game over screen
	# row 15 block 18
	# formula: 128*15 + 16*4
	lw $t0, displayAddress
	addi $t0, $t0, 1984
	sw $t0, scoreAddress
	jal display_score
	
	restart_loop:
		lw $t0, 0xffff0000
		beq $t0, 1, restart_detection
		j restart_loop
	restart_detection:
		lw $t0, 0xffff0004
		# see if user pressed space button
		beq $t0, 0x73, restart_action
		beq $t0, 0x65, exit_action
		j restart_loop
	restart_action:
		# change jumoOrFall to jump always at start
		li $t0, 0
		sw $t0, jumpOrFall
		
		# reset the score to 0
		sw $t0, score
		
		# reset the scoreAddress
		li $t0, 0x10008074
		sw $t0, scoreAddress
		
		# reset the sleep time
		li $t0, 80
		sw $t0, sleepTime
		j main
	exit_action:
	
	li $v0, 10 # terminate the program gracefully
	syscall
