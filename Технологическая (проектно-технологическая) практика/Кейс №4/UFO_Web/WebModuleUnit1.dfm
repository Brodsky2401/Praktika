object WebModule1: TWebModule1
  OldCreateOrder = False
  OnCreate = WebModuleCreate
  OnDestroy = WebModuleDestroy
  Actions = <
    item
      Default = True
      Name = 'DefaultHandler'
      PathInfo = '/'
      OnAction = WebModule1DefaultHandlerAction
    end
    item
      Name = 'ReportsAction'
      PathInfo = '/reports'
      OnAction = WebModule1ReportsAction
    end
    item
      Name = 'StatsAction'
      PathInfo = '/stats'
      OnAction = WebModule1StatsAction
    end
    item
      Name = 'AddReportAction'
      PathInfo = '/add'
      OnAction = WebModule1AddReportAction
    end
    item
      Name = 'GetJSONAction'
      PathInfo = '/api/data'
      OnAction = WebModule1GetJSONAction
    end
    item
      Name = 'DBAction'
      PathInfo = '/admin/db'
      OnAction = WebModule1DBAction
    end>
  Height = 375
  Width = 544
  object PageProducer1: TPageProducer
    HTMLDoc.Strings = (
      '<html>'
      '<head><title>UFOWeb MSSQL</title></head>'
      '<body>'
      '<h1>UFO Database - SQL Server</h1>'
      '<p>Time: <#DATETIME></p>'
      '<p>Version: <#VERSION></p>'
      '</body>'
      '</html>')
    OnHTMLTag = PageProducer1HTMLTag
    Left = 200
    Top = 96
  end
  object FDConnection1: TFDConnection
    Params.Strings = (
      'Server=localhost\SQLEXPRESS'
      'Database=UFOWebDB'
      'Trusted_Connection=Yes'
      'Mars=Yes'
      'ApplicationName=UFOWeb')
    LoginPrompt = False
    Left = 304
    Top = 96
  end
  object FDQuery1: TFDQuery
    Connection = FDConnection1
    Left = 384
    Top = 96
  end
  object FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink
    Left = 464
    Top = 96
  end
end