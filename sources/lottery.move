module delottery::DeLottery {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID,ID};
    //use delottery::vec_map::{Self, VecMap};
    use sui::vec_map::{Self, VecMap};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use std::debug;
    use sui::transfer;
    use sui::event;
    use sui::sui::SUI;
    //use std::option::{Self, Option};

    //address payable[] public players;
    const STATE_OPEN:u8 = 0 ;
    const STATE_CLOSED:u8 = 1;
    const STATE_CALCULATING_WINNER:u8 = 2;
    const EWrongAmount: u64 = 0;
    const EWrongGameState: u64 = 1;
    struct Game has key{
        id:UID,
        //tickets: vector<Ticket>,
        tickets: VecMap<ID, Ticket>,
        balance: Balance<SUI>,
        admin: address,
        price: u64,
        state:u8,
    }
    struct Ticket has key,store{
        id:UID,
        ptid : ID,
        player : address,
        numbers :vector<u8>,
    }
    struct PlayerTicket has key,store{
        id:UID,
        gtid: ID,
    }
    struct GameCreateEv has copy, drop {
        id: ID,
    }
    struct TicketCreateEv has copy, drop {
        id: ID,
        uid:ID,
    }
    fun init(_ctx: &mut TxContext) {
    }
    fun startGame(price:u64,ctx: &mut TxContext){  
        let id = object::new(ctx);
        let for = object::uid_to_inner(&id);
        let game = Game{
            state:STATE_OPEN,
            id: id,
            price:price,
            admin: tx_context::sender(ctx),
            balance:balance::zero<SUI>(),
            tickets:vec_map::empty(),//vector::empty<Ticket>(),
        };
        debug::print(&game);
        transfer::share_object(game);
        event::emit(GameCreateEv { id:for });
    }
    fun endGame(game: &mut Game, ctx: &mut TxContext){
        assert!(game.state ==STATE_OPEN, EWrongGameState);
        assert!(game.admin ==tx_context::sender(ctx), EWrongGameState);
        game.state = STATE_CLOSED;
    }
    fun calculating_winner(game:&mut Game, numbers:vector<u8>,ctx: &mut TxContext){
        assert!(game.admin ==tx_context::sender(ctx), EWrongGameState);
        let n = vec_map::size(&game.tickets);
        let i = 0;
        while (i < n) {
            let (_,v) = vec_map::get_entry_by_idx_mut(&mut game.tickets,i);
            if(v.numbers == numbers){
                debug::print(&v.player);
            };
            i = i+1;
        };
    }
    public entry fun buyTicket(game: &mut Game,payment: &mut Coin<SUI>,numbers:vector<u8>, ctx: &mut TxContext) {
        assert!(game.state ==STATE_OPEN, EWrongGameState);
        assert!(coin::value(payment) >= game.price, EWrongAmount);
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, game.price);
        balance::join(&mut game.balance, paid);
        let tid = object::new(ctx);
        let sender = tx_context::sender(ctx);
        let playerTicket = PlayerTicket{
            id: object::new(ctx),
            gtid:object::uid_to_inner(&tid),

        };
       
        let ticket = Ticket{
            id :tid,
            ptid: object::uid_to_inner(&playerTicket.id),
            numbers :numbers,
            player : sender,
        };
        let eid = object::uid_to_inner(&ticket.id);
        vec_map::insert(&mut game.tickets,playerTicket.gtid, ticket);
        playerTicket.gtid = eid;
        
        let ev = TicketCreateEv { id: eid,uid:object::uid_to_inner(&playerTicket.id)};
        debug::print(&ev);
        event::emit(ev);
        transfer::transfer(playerTicket, sender);
        //object::delete(tid);
    }
    public fun getTicket(_game: &mut Game, _id: ID,_ctx: &mut TxContext){

    }
    #[test]
    public fun test_start(){
        //use sui::tx_context;
        use std::debug;
        use sui::test_scenario;
        use sui::pay;
        use std::string;
        let admin = @0xAD014;
        let player = @0xAD015;
        let player2 = @0xAD016;
        
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        //assert!(scenario!=0u64,100);
        test_scenario::next_tx(scenario, admin);
        {
            init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, admin);
        {
            startGame(100,test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);
            debug::print(&game);
            test_scenario::return_shared(game);
        };
        test_scenario::next_tx(scenario, player); 
        {
            let game = test_scenario::take_shared<Game>(scenario);
            let num_coins = 1000;
            let sui = coin::mint_for_testing<SUI>(num_coins, test_scenario::ctx(scenario));
            let keys: vector<u8> = vector[1, 3, 2, 7, 9,17,21];
            buyTicket(&mut game,&mut sui,keys,test_scenario::ctx(scenario));
            debug::print(&coin::value(&sui));
            debug::print(&vec_map::size(&game.tickets));
            pay::keep(sui, test_scenario::ctx(scenario));
            test_scenario::return_shared(game);
        };
        test_scenario::next_tx(scenario, player2); 
        {
            let game = test_scenario::take_shared<Game>(scenario);
            let num_coins = 2000;
            let sui = coin::mint_for_testing<SUI>(num_coins, test_scenario::ctx(scenario));
            let keys: vector<u8> = vector[1, 3, 5, 7, 9,17,21];
            buyTicket(&mut game,&mut sui,keys,test_scenario::ctx(scenario));
            debug::print(&coin::value(&sui));
            debug::print(&vec_map::size(&game.tickets));
            pay::keep(sui, test_scenario::ctx(scenario));
            test_scenario::return_shared(game);
        };
        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);
            debug::print(&game.balance);
            test_scenario::return_shared(game);
        }; 
        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);
            endGame(&mut game,test_scenario::ctx(scenario));
            debug::print(&game.balance);
            test_scenario::return_shared(game);
        }; 
        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);
            let keys: vector<u8> = vector[1, 3, 5, 7, 9,17,21];
            let start = string::utf8(b"calculating_winner start");
            debug::print(&start);
            calculating_winner(&mut game,keys,test_scenario::ctx(scenario));
            let end = string::utf8(b"calculating_winner end");
            debug::print(&end);
           // endGame(&mut game,test_scenario::ctx(scenario));
            debug::print(&game.balance);
            test_scenario::return_shared(game);
        }; 
        /*test_scenario::next_tx(scenario, player2); 
        {
            let game = test_scenario::take_shared<Game>(scenario);
            let num_coins = 2000;
            let sui = coin::mint_for_testing<SUI>(num_coins, test_scenario::ctx(scenario));
            let keys: vector<u8> = vector[1, 3, 5, 7, 9,17,21];
            buyTicket(&mut game,&mut sui,keys,test_scenario::ctx(scenario));
            debug::print(&coin::value(&sui));
            debug::print(&vec_map::size(&game.tickets));
            pay::keep(sui, test_scenario::ctx(scenario));
            test_scenario::return_shared(game);
        };*/

        /*test_scenario::next_tx(scenario, player2); 
        {
            let game = test_scenario::take_shared<Game>(scenario);
            buyTicket(&mut game,test_scenario::ctx(scenario));
            debug::print(&game.tickets);
            debug::print(&vec_map::size(&game.tickets));
            test_scenario::return_shared(game);
        };*/
        test_scenario::end(scenario_val);
    }

}