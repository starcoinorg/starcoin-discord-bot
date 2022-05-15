address admin{
    module StarcoinBotv1beta{
        use StarcoinFramework::Signer;
        use StarcoinFramework::Token;
        use StarcoinFramework::Account;
        use StarcoinFramework::Config;
        use StarcoinFramework::NFT;
        use StarcoinFramework::Vector;
        use StarcoinFramework::NFTGallery;
        use StarcoinFramework::Option;
        use StarcoinFramework::Event;

        const DEFAULT_ADMIN: address = @admin;

        struct GalleryList<Meta: copy + store + drop, Body: store> has store,key{
            resourceList : vector<ResourceList<Meta,Body>>,
        }

        struct ResourceList<Meta: copy + store + drop, Body: store> has store,key{
            id:u64,
            owner:address,
            nft:NFT::NFT<Meta,Body>
        }
        struct StarcoinBotv1Admin has copy, drop, store {
            admin: address,
        }

        struct ResourceBank<phantom T:store> has store,key{
            bank:Token::Token<T>
        }

        struct SendTokenEvent has store,drop{
            amount:u128,
            from:address,
            to:address,
            token_type:Token::TokenCode
        }

        struct WithdrawTokenEvent has store,drop{
            amount:u128,
            from:address,
            to:address,
            token_type:Token::TokenCode
        }

        struct DepositTokenEvent has store,drop{
            amount:u128,
            from:address,
            to:address,
            token_type:Token::TokenCode
        }

        struct StarcoinBotBankEvent<phantom T:store> has store,key{
            send_token_event_handler:       Event::EventHandle<SendTokenEvent>,
            withdraw_token_event_handler:   Event::EventHandle<WithdrawTokenEvent>,
            deposit_token_event_handler:    Event::EventHandle<DepositTokenEvent>,
        }


        struct SendNFTEvent< phantom Meta: copy + store + drop> has store,drop{
            id:u64,
            from:address,
            to:address,
        }

        struct WithdrawNFTEvent<phantom Meta: copy + store + drop> has store,drop{
            id:u64,
            from:address,
            to:address,
        }

        struct DepositNFTEvent<phantom Meta: copy + store + drop> has store,drop{
            id:u64,
            from:address,
            to:address,
        }

        struct StarcoinBotGalleryListEvent<phantom Meta: copy + store + drop> has store,key{
            send_nft_event_handler:       Event::EventHandle<SendNFTEvent<Meta>>,
            withdraw_nft_event_handler:   Event::EventHandle<WithdrawNFTEvent<Meta>>,
            deposit_nft_event_handler:    Event::EventHandle<DepositNFTEvent<Meta>>,
        }

        public fun is_have_galleryList<Meta: copy + store + drop, Body: store>():bool{
            return exists<GalleryList<Meta,Body>>( admin() )
        }

        public fun is_admin(addr:address):bool{
            return  ( admin() == addr ) || ( DEFAULT_ADMIN == addr ) 
        }

        public fun admin():address{
            if (Config::config_exist_by_address<StarcoinBotv1Admin>(DEFAULT_ADMIN)) {
                let conf = Config::get_by_address<StarcoinBotv1Admin>(DEFAULT_ADMIN); 
                conf.admin
            } else {
                DEFAULT_ADMIN
            }
        }

        public fun set_admin(account:&signer,addr:address){
            let user_addr = Signer::address_of( account );
            assert!( is_admin( user_addr ) ,200010);
            let config = StarcoinBotv1Admin{
                admin: addr,
            };
            if (Config::config_exist_by_address<StarcoinBotv1Admin>(DEFAULT_ADMIN)) {
                Config::set<StarcoinBotv1Admin>(account, config);
            } else {
                Config::publish_new_config<StarcoinBotv1Admin>(account, config);
            }
        }

        public (script) fun init_bank<TokenType: store >( signer: signer , amount: u128 )   {
            let account = &signer;
            let user_addr = Signer::address_of( account );
            assert!( ! exists<ResourceBank<TokenType>>( user_addr ) , 10003 );
            assert!(   Account::balance<TokenType>( user_addr ) >= amount , 10004 );
            
            let token = Account::withdraw<TokenType>( account , amount );
            
            move_to(account,ResourceBank<TokenType>{
                bank : token
            });

            move_to(account, StarcoinBotBankEvent<TokenType>{
                send_token_event_handler:       Event::new_event_handle<SendTokenEvent>(account),
                withdraw_token_event_handler:   Event::new_event_handle<WithdrawTokenEvent>(account),
                deposit_token_event_handler:    Event::new_event_handle<DepositTokenEvent>(account),
            });
        }

        public (script) fun init_gallery_list<Meta: copy + store + drop, Body: store>( signer: signer )  {
            let account = &signer;
            let user_addr = Signer::address_of( account );
            assert!( is_admin(  user_addr ) ,200010);
            assert!( ! exists<GalleryList<Meta , Body>>( user_addr ) , 10004 );
            move_to(account,GalleryList<Meta , Body>{
                resourceList : Vector::empty<ResourceList<Meta,Body>>(),
            });
            move_to(account, StarcoinBotGalleryListEvent<Meta>{
                send_nft_event_handler:       Event::new_event_handle<SendNFTEvent<Meta>>(account),
                withdraw_nft_event_handler:   Event::new_event_handle<WithdrawNFTEvent<Meta>>(account),
                deposit_nft_event_handler:    Event::new_event_handle<DepositNFTEvent<Meta>>(account),
            });
        }

        public (script) fun withdraw_nft<Meta: copy + store + drop, Body: store>(signer: signer, pos: u64 , id: u64 , to: address ) acquires GalleryList ,StarcoinBotGalleryListEvent {
            let account = &signer;
            let user_addr = Signer::address_of( account );
            if( NFTGallery::is_accept<Meta,Body>( user_addr ) ) {
                if( user_addr == to ){
                    NFTGallery::accept<Meta,Body>( account );
                }else{
                    assert!( NFTGallery::is_accept<Meta,Body>( to ),100039);
                }
            };
            let gallerylist = borrow_global_mut<GalleryList<Meta , Body >>( admin() );
            
            let length  = Vector::length<ResourceList<Meta,Body>>( &gallerylist.resourceList );

            assert!( length >= pos + 1 , 103302 );
            
            let resource = Vector::borrow_mut<ResourceList<Meta,Body>>(&mut gallerylist.resourceList , pos );
            
            assert!( resource.id == id , 100100 );
            assert!( resource.owner == user_addr , 100101 );


            let ResourceList <Meta,Body> {
                id:_,
                owner:_,
                nft:nft
            } = Vector::remove<ResourceList<Meta,Body>>(&mut gallerylist.resourceList , pos );
            
            NFTGallery::deposit_to<Meta,Body>( to , nft );

            let gallery_nft_event = borrow_global_mut<StarcoinBotGalleryListEvent<Meta>>( admin() );
            Event::emit_event(&mut gallery_nft_event.withdraw_nft_event_handler, WithdrawNFTEvent<Meta> {
                id:id,
                from:user_addr,
                to:to,
            });
        }

        public (script) fun deposit_nft<Meta: copy + store + drop, Body: store>(signer: signer , id: u64 ) acquires GalleryList,StarcoinBotGalleryListEvent {
            let account = &signer;
            assert!(is_have_galleryList< Meta  , Body >() , 100421);
            let user_addr = Signer::address_of( account );
            assert!( NFTGallery::is_accept<Meta,Body>( user_addr ) , 100301 ) ;
            let op_nft = NFTGallery::withdraw<Meta,Body>( account , id );
            assert!( Option::is_some( &op_nft ) , 104423);
            let nft = Option::destroy_some<NFT::NFT<Meta,Body>>( op_nft);
            let gallerylist = borrow_global_mut<GalleryList<Meta , Body >>( admin() );
            
            
            Vector::push_back<ResourceList<Meta , Body >>(&mut gallerylist.resourceList , ResourceList<Meta , Body >{
                id: NFT::get_id< Meta, Body>( &nft ),
                owner:user_addr,
                nft:nft
            });

            let gallery_nft_event = borrow_global_mut<StarcoinBotGalleryListEvent<Meta>>( admin() );
            Event::emit_event(&mut gallery_nft_event.deposit_nft_event_handler, DepositNFTEvent<Meta> {
                id:id,
                from:user_addr,
                to:user_addr,
            });

        }

        public (script) fun send_nft<Meta: copy + store + drop, Body: store>(signer:signer , from:address, pos:u64 , id:u64 , to:address )acquires GalleryList ,StarcoinBotGalleryListEvent{
            let account = &signer;
            
            let user_addr = Signer::address_of( account );

            assert!( is_admin( user_addr ) ,200010);
            
            let gallerylist = borrow_global_mut<GalleryList<Meta , Body >>( admin() );
            
            let length  = Vector::length<ResourceList<Meta,Body>>( &gallerylist.resourceList );

            assert!( length >= pos + 1 , 103302 );
            
            let resource = Vector::borrow_mut<ResourceList<Meta,Body>>(&mut gallerylist.resourceList , pos );
            
            assert!( resource.id == id , 100100 );
            assert!( resource.owner == from , 100101 );

            resource.owner = to ;

            let gallery_nft_event = borrow_global_mut<StarcoinBotGalleryListEvent<Meta>>( admin() );
            Event::emit_event(&mut gallery_nft_event.send_nft_event_handler, SendNFTEvent<Meta> {
                id:id,
                from:user_addr,
                to:to,
            });
        }

        public (script) fun send_token<TokenType: store>(signer:signer,from:address,amount :u128,to:address) acquires ResourceBank,StarcoinBotBankEvent{
            let account = &signer;
            let user_addr = Signer::address_of( account );
            assert!( is_admin(user_addr) , 100301);
            assert!( exists<ResourceBank<TokenType>>( from ) , 1000310);
            let from_resourcebank =  borrow_global_mut<ResourceBank<TokenType>>( from );
            
            let token = Token::withdraw<TokenType>(&mut from_resourcebank.bank , amount);

            if( exists<ResourceBank<TokenType>>( to )){
                let to_resourcebank = borrow_global_mut<ResourceBank<TokenType>>( to );
                Token::deposit<TokenType>( &mut to_resourcebank.bank , token );
            }else{
                Account::deposit<TokenType>( to , token);
            };

            let token_event = borrow_global_mut<StarcoinBotBankEvent<TokenType>>( admin() );
            Event::emit_event(&mut token_event.send_token_event_handler, SendTokenEvent {
                amount:amount,
                from:from,
                to:to,
                token_type:Token::token_code<TokenType>()
            });
        }

        public (script) fun withdraw_token<TokenType:store >(signer :signer, amount :u128) acquires ResourceBank,StarcoinBotBankEvent{
            let account = &signer;
            let user_addr = Signer::address_of( account );
            assert!( exists<ResourceBank<TokenType>>( user_addr ) , 1000310);
            let resourcebank =  borrow_global_mut<ResourceBank<TokenType>>( user_addr );
            let token = Token::withdraw<TokenType>(&mut resourcebank.bank , amount);
            Account::deposit<TokenType>( user_addr , token);
            
            let token_event = borrow_global_mut<StarcoinBotBankEvent<TokenType>>( admin() );
            Event::emit_event(&mut token_event.withdraw_token_event_handler, WithdrawTokenEvent {
                amount:amount,
                from:user_addr,
                to:user_addr,
                token_type:Token::token_code<TokenType>()
            });
        }

        public (script) fun deposit_token<TokenType:store>(signer:signer,amount :u128) acquires ResourceBank,StarcoinBotBankEvent{
            let account = &signer;
            let user_addr = Signer::address_of( account );
            assert!(   Account::balance<TokenType>( user_addr ) >= amount , 10004 );
            let token = Account::withdraw<TokenType>( account , amount );
            if( exists<ResourceBank<TokenType>>( user_addr )){
                let resourcebank = borrow_global_mut<ResourceBank<TokenType>>( user_addr );
                Token::deposit<TokenType>( &mut resourcebank.bank , token );
            }else{
                move_to(account,ResourceBank<TokenType>{
                    bank : token
                });
            };
            let token_event = borrow_global_mut<StarcoinBotBankEvent<TokenType>>( admin() );
            Event::emit_event(&mut token_event.deposit_token_event_handler, DepositTokenEvent {
                amount:amount,
                from:user_addr,
                to:user_addr,
                token_type:Token::token_code<TokenType>()
            });
        }


    }
}
