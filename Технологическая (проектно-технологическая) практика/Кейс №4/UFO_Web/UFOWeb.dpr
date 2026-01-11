program UFOWeb;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Web.WebBroker,
  Web.WebReq,
  IdHTTPWebBrokerBridge,
  WebModuleUnit1 in 'WebModuleUnit1.pas';

{$R *.res}

var
  Server: TIdHTTPWebBrokerBridge;

begin
  try
    ReportMemoryLeaksOnShutdown := True;
    
    Writeln('=========================================');
    Writeln('           UFOWeb Server v2.0');
    Writeln('=========================================');
    Writeln('База данных: Microsoft SQL Server');
    Writeln('Аутентификация: Windows Authentication');
    Writeln('Подключение к: localhost\SQLEXPRESS');
    Writeln('База данных: UFOWebDB');
    Writeln('');
    Writeln('Проверка перед запуском:');
    Writeln('1. SQL Server Express должен быть установлен');
    Writeln('2. Служба "SQL Server (SQLEXPRESS)" запущена');
    Writeln('3. Windows Authentication включена');
    Writeln('=========================================');
    
    // Создаем HTTP сервер
    Server := TIdHTTPWebBrokerBridge.Create(nil);
    try
      // Регистрируем веб-модуль
      if WebRequestHandler <> nil then
      begin
        WebRequestHandler.WebModuleClass := TWebModule1;
        Writeln('✅ WebModule registered: TWebModule1');
      end;
      
      // Настройки сервера
      Server.DefaultPort := 8080;
      Server.Active := True;
      
      Writeln('✅ Server started successfully!');
      Writeln('🌐 URL: http://localhost:8080');
      Writeln('');
      Writeln('Доступные endpoints:');
      Writeln('  /              - Главная страница');
      Writeln('  /reports       - Все отчеты о НЛО');
      Writeln('  /add           - Добавить новый отчет');
      Writeln('  /stats         - Статистика');
      Writeln('  /api/data      - JSON API для данных');
      Writeln('  /admin/db      - Управление базой данных');
      Writeln('');
      Writeln('Нажмите Enter для остановки сервера...');
      Writeln('=========================================');
      
      // Ожидаем Enter для остановки
      Readln;
      
      Writeln('🛑 Stopping server...');
      Server.Active := False;
      
    finally
      Server.Free;
    end;
    
    Writeln('✅ Server stopped.');
    
  except
    on E: Exception do
    begin
      Writeln('❌ ERROR: ' + E.ClassName);
      Writeln('   Message: ' + E.Message);
      Writeln('');
      Writeln('Нажмите Enter для выхода...');
      Readln;
    end;
  end;
end.