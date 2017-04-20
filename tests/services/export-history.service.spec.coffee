describe "ExportHistory service", ->
  $rootScope = undefined
  Wallet = undefined
  ExportHistory = undefined
  MyBlockchainApi = undefined

  beforeEach angular.mock.module("walletApp")

  beforeEach ->
    angular.mock.inject ($injector, _$rootScope_, $q) ->
      $rootScope = _$rootScope_
      Wallet = $injector.get("Wallet")
      ExportHistory = $injector.get("ExportHistory")
      MyBlockchainApi = $injector.get("MyBlockchainApi")

      Wallet.settings.currency = { code: 'USD' }

      Wallet.my.wallet =
        getNote: (-> )
        getHistory: () -> $q.resolve()

      MyBlockchainApi.exportHistory = () ->

  describe "json2csv", ->
    it "should convert json to csv", ->
      json = [{ a: 1, b: 'x' }, { a: 2, b: 'y' }, { a: 3, b: 'z' }]
      csv = 'a,b\n1,"x"\n2,"y"\n3,"z"'
      expect(ExportHistory.json2csv(json)).toEqual(csv)

  describe "escapeCSV", ->
    it "should not escape a normal string", ->
      expect(ExportHistory.escapeCSV("abc")).toEqual("abc")

    it "should excape all blacklisted symbols", ->
      blacklist = ["+", "=", "-"]
      for symbol in blacklist
        expect(ExportHistory.escapeCSV("#{symbol}abc")).toEqual("'#{symbol}abc")

  describe "addNoteToTx", ->
    it "should add the correct note to a tx object", ->
      tx = { tx: 'asdf', note: null }
      spyOn(Wallet, 'getNote').and.callFake((hash) -> hash == 'asdf' && 'test_note')
      ExportHistory.addNoteToTx(tx)
      expect(tx.note).toEqual('test_note')

    it "should escape the note if necessary", ->
      tx = { tx: 'asdf', note: null }
      spyOn(Wallet, 'getNote').and.callFake((hash) -> hash == 'asdf' && "=evil")
      ExportHistory.addNoteToTx(tx)
      expect(tx.note).toEqual("'=evil")

  describe "with transactions", ->
    beforeEach ->
      history = [{ sent: 1, receive: 0, tx: 'asdf' }, { sent: 0, receive: 2, tx: 'qwer' }]
      spyOn(MyBlockchainApi, 'exportHistory').and.returnValue(history)

    it "should call API.exportHistory with correct arguments", ->
      ExportHistory.fetch('01/01/2015', '01/01/2016', ['1asdf'])
      expect(MyBlockchainApi.exportHistory).toHaveBeenCalledWith(['1asdf'], 'USD', { start: '01/01/2015', end: '01/01/2016' })

    it "should convert to csv with notes and broadcast broadcast download event", (done) ->
      spyOn(Wallet, 'getNote').and.callFake((hash) -> hash == 'asdf' && 'test_note')
      spyOn($rootScope, '$broadcast')
      ExportHistory.fetch().then (data) ->
        expect(data).toEqual('sent,receive,tx,note\n1,0,"asdf","test_note"\n0,2,"qwer",""')
        done()
      $rootScope.$digest()

  describe "with no transactions", ->
    beforeEach ->
      spyOn(MyBlockchainApi, 'exportHistory').and.returnValue([])

    it "should show an error", (done) ->
      ExportHistory.fetch().catch (e) ->
        expect(e).toEqual('NO_HISTORY')
        done()
      $rootScope.$digest()
